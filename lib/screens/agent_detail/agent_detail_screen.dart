import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/agent_intent.dart';
import '../../../core/api_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/agent.dart';
import '../../../providers/agents_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/app_lifecycle_provider.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/artifact_tile.dart';
import '../../widgets/error_view.dart';

/// Agent detail: status, conversation, artifacts, follow-up input, PR link.
/// Polling pauses when app is in background so connection stays stable on resume.
class AgentDetailScreen extends ConsumerStatefulWidget {
  const AgentDetailScreen({super.key, required this.agentId});

  final String agentId;

  @override
  ConsumerState<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends ConsumerState<AgentDetailScreen> {
  final _messageController = TextEditingController();
  Timer? _pollTimer;
  bool _sending = false;
  AgentIntent _intent = AgentIntent.ask;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _messageController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(agentDetailProvider(widget.agentId));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    final effectiveText = buildPromptForIntent(_intent, text);
    setState(() => _sending = true);
    _messageController.clear();
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendMessage(widget.agentId, effectiveText);
      ref.invalidate(conversationProvider(widget.agentId));
      ref.invalidate(agentDetailProvider(widget.agentId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    // Pause polling when app goes to background; resume when back in foreground
    ref.listen<bool>(isAppForegroundProvider, (prev, next) {
      if (next == false) {
        _stopPolling();
      } else if (next == true && mounted) {
        _startPolling();
      }
    });

    final agentAsync = ref.watch(agentDetailProvider(widget.agentId));
    final conversationAsync = ref.watch(conversationProvider(widget.agentId));
    final artifactsAsync = ref.watch(artifactsProvider(widget.agentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(agentDetailProvider(widget.agentId));
              ref.invalidate(conversationProvider(widget.agentId));
              ref.invalidate(artifactsProvider(widget.agentId));
            },
          ),
        ],
      ),
      body: agentAsync.when(
        data: (agent) {
          if (agent == null) {
            return const Center(child: Text('Agent not found'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agentDetailProvider(widget.agentId));
              ref.invalidate(conversationProvider(widget.agentId));
              ref.invalidate(artifactsProvider(widget.agentId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusSection(agent: agent),
                  if (agent.pullRequestUrl != null) _PrLink(url: agent.pullRequestUrl!),
                  const Divider(height: 24),
                  Text(
                    'Conversation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  conversationAsync.when(
                    data: (conv) {
                      if (conv.messages.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No messages yet.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        );
                      }
                      return Column(
                        children: conv.messages.map((m) => ChatBubble(message: m)).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => ErrorView(message: apiErrorMessage(e)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Artifacts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  artifactsAsync.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No artifacts.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        );
                      }
                      return Column(
                        children: list.map((a) => ArtifactTile(artifact: a)).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => ErrorView(message: apiErrorMessage(e)),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(agentDetailProvider(widget.agentId)),
        ),
      ),
      bottomSheet: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<AgentIntent>(
                      segments: const [
                        ButtonSegment(
                          value: AgentIntent.ask,
                          label: Text('Ask'),
                          icon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                        ButtonSegment(
                          value: AgentIntent.plan,
                          label: Text('Plan'),
                          icon: Icon(Icons.route_rounded),
                        ),
                        ButtonSegment(
                          value: AgentIntent.debug,
                          label: Text('Debug'),
                          icon: Icon(Icons.bug_report_rounded),
                        ),
                      ],
                      selected: {_intent},
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) return;
                        setState(() => _intent = selection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Follow-up message (${_intent.label})...',
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _sendMessage,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _intent.shortDescription,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context) {
    final color = agent.isRunning
        ? AppColors.statusRunning
        : agent.isFinished
            ? AppColors.statusFinished
            : AppColors.statusFailed;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(agent.status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                  ),
                  if (agent.repoName != null) ...[
                    const Spacer(),
                    Flexible(
                      child: Text(
                        agent.repoName!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
              if (agent.summary != null && agent.summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(agent.summary!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrLink extends StatelessWidget {
  const _PrLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: const Icon(Icons.link_rounded),
        title: const Text('View Pull Request'),
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ),
    );
  }
}
