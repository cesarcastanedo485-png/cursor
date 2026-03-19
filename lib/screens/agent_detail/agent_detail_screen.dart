import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/agent.dart';
import '../../../providers/agents_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/artifact_tile.dart';
import '../../widgets/error_view.dart';

/// Agent detail: status, conversation, artifacts, follow-up input, PR link.
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

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(agentDetailProvider(widget.agentId));
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendMessage(widget.agentId, text);
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
              padding: const EdgeInsets.only(bottom: 100),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Follow-up message...',
                        border: OutlineInputBorder(),
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
                      color: color.withOpacity(0.2),
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
