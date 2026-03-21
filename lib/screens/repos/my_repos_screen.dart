import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/agent_intent.dart';
import '../../core/api_errors.dart';
import '../../data/models/cursor_repository.dart';
import '../../providers/repositories_provider.dart';
import '../../providers/shell_providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

/// Shown when Cursor returns 401 on /v0/repositories (backend issue).
const String _reposUnauthorizedMessage =
    "Cursor’s repo list API is returning “unauthorized” even though your key works for agents. This is a known backend issue.\n\n"
    "Add your repos manually below so you can still launch agents (e.g. streamgame). When Cursor fixes the API, the full list will load here.";

/// Searchable list of GitHub repos from Cursor API.
class MyReposScreen extends ConsumerStatefulWidget {
  const MyReposScreen({super.key});

  @override
  ConsumerState<MyReposScreen> createState() => _MyReposScreenState();
}

class _MyReposScreenState extends ConsumerState<MyReposScreen> {
  final _search = TextEditingController();
  bool _wasReposTabVisible = false;
  bool _autoRefreshingOnTabEnter = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _launchOnRepo(String url, AgentIntent intent) {
    ref.read(launchRepoPrefillProvider.notifier).state = url;
    ref.read(launchIntentPrefillProvider.notifier).state = intent;
    ref.read(mainShellTabProvider.notifier).state = 0;
    ref.read(cloudAgentsSubTabProvider.notifier).state = 1;
  }

  Future<void> _pickLaunchIntentAndGo(String url) async {
    final selected = await showModalBottomSheet<AgentIntent>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rocket_launch_rounded),
              title: const Text('Launch'),
              subtitle: Text(AgentIntent.normal.shortDescription),
              onTap: () => Navigator.of(ctx).pop(AgentIntent.normal),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Ask'),
              subtitle: Text(AgentIntent.ask.shortDescription),
              onTap: () => Navigator.of(ctx).pop(AgentIntent.ask),
            ),
            ListTile(
              leading: const Icon(Icons.route_rounded),
              title: const Text('Plan'),
              subtitle: Text(AgentIntent.plan.shortDescription),
              onTap: () => Navigator.of(ctx).pop(AgentIntent.plan),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_rounded),
              title: const Text('Debug'),
              subtitle: Text(AgentIntent.debug.shortDescription),
              onTap: () => Navigator.of(ctx).pop(AgentIntent.debug),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    _launchOnRepo(url, selected);
  }

  /// Quick launch: skip intent picker, use Launch (normal) with default model.
  void _quickLaunchOnRepo(String url) {
    _launchOnRepo(url, AgentIntent.normal);
  }

  void _showAddRepoDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add repo by URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://github.com/owner/repo',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
          onSubmitted: (_) => _addManualRepo(controller.text.trim(), ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addManualRepo(controller.text.trim(), ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualRepo(String url, BuildContext dialogContext) async {
    if (url.isEmpty) return;
    final repo = CursorRepository.fromUrl(url);
    if (repo == null) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('Enter a valid GitHub URL (e.g. https://github.com/owner/repo)')),
        );
      }
      return;
    }
    await ref.read(manualReposProvider.notifier).addUrl(url);
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
  }

  Future<void> _safeRefresh() async {
    await ref.read(repositoriesProvider.notifier).refresh();
  }

  Future<void> _forceApiRetry() async {
    await ref.read(repositoriesProvider.notifier).forceApiRetry();
  }

  void _maybeAutoRefreshOnTabEntry(bool isReposTabVisible, AsyncValue<List<CursorRepository>> async) {
    if (isReposTabVisible && !_wasReposTabVisible && async.hasError && !_autoRefreshingOnTabEnter) {
      _autoRefreshingOnTabEnter = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await _safeRefresh();
        } finally {
          _autoRefreshingOnTabEnter = false;
        }
      });
    }
    _wasReposTabVisible = isReposTabVisible;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(repositoriesProvider);
    final subTab = ref.watch(cloudAgentsSubTabProvider).clamp(0, 3);
    final manualRepos = ref.watch(manualReposProvider);
    final antiLoopMsg = ref.watch(reposAntiLoopMessageProvider);
    final q = _search.text.trim().toLowerCase();
    _maybeAutoRefreshOnTabEntry(subTab == 2, async);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRepoDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add repo'),
        tooltip: 'Add repo by URL (e.g. https://github.com/owner/repo)',
      ),
      appBar: AppBar(
        title: const Text('My Repos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link_rounded),
            tooltip: 'Add repo by URL',
            onPressed: _showAddRepoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh (respects anti-loop)',
            onPressed: _safeRefresh,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'force') _forceApiRetry();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'force',
                child: Text('Force API retry (bypass pause)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (antiLoopMsg != null && antiLoopMsg.isNotEmpty)
            MaterialBanner(
              content: Text(antiLoopMsg),
              leading: const Icon(Icons.pause_circle_outline_rounded),
              actions: [
                TextButton(
                  onPressed: () => ref.read(reposAntiLoopMessageProvider.notifier).state = null,
                  child: const Text('Dismiss'),
                ),
                TextButton(
                  onPressed: _forceApiRetry,
                  child: const Text('Force retry'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search repositories…',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: async.when(
              data: (apiRepos) {
                final combined = <CursorRepository>[];
                final seen = <String>{};
                for (final r in apiRepos) {
                  final u = r.repoUrl;
                  if (seen.add(u)) combined.add(r);
                }
                for (final r in manualRepos) {
                  final u = r.repoUrl;
                  if (seen.add(u)) combined.add(r);
                }
                final filtered = q.isEmpty
                    ? combined
                    : combined.where((r) {
                        final n = '${r.name} ${r.fullName} ${r.description}'.toLowerCase();
                        return n.contains(q);
                      }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        combined.isEmpty
                            ? 'No repos yet. Pull to refresh, or tap + to add a repo by URL (e.g. streamgame).'
                            : 'No matches',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _safeRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final repo = filtered[i];
                      final isManual = manualRepos.any((m) => m.repoUrl == repo.repoUrl);
                      return _RepoCard(
                        repo: repo,
                        onLaunch: () => _quickLaunchOnRepo(repo.repoUrl),
                        onLaunchWithIntent: () => _pickLaunchIntentAndGo(repo.repoUrl),
                        isManual: isManual,
                        onRemove: isManual
                            ? () => ref.read(manualReposProvider.notifier).removeUrl(repo.repoUrl)
                            : null,
                      );
                    },
                  ),
                );
              },
              loading: () {
                if (manualRepos.isEmpty) return const LoadingSkeleton();
                return CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: LoadingSkeleton()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Your manual repos',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _RepoCard(
                          repo: manualRepos[i],
                          onLaunch: () => _quickLaunchOnRepo(manualRepos[i].repoUrl),
                          onLaunchWithIntent: () => _pickLaunchIntentAndGo(manualRepos[i].repoUrl),
                          isManual: true,
                          onRemove: () => ref.read(manualReposProvider.notifier).removeUrl(manualRepos[i].repoUrl),
                        ),
                        childCount: manualRepos.length,
                      ),
                    ),
                  ],
                );
              },
              error: (e, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ErrorView(
                        title: isUnauthorizedError(e) ? 'Invalid API key' : null,
                        message: isUnauthorizedError(e)
                            ? _reposUnauthorizedMessage
                            : apiErrorMessage(e),
                        onRetry: _safeRefresh,
                        onSecondary: isUnauthorizedError(e)
                            ? () {
                                ref.read(mainShellTabProvider.notifier).state = 0;
                                ref.read(cloudAgentsSubTabProvider.notifier).state = 3;
                              }
                            : null,
                        secondaryLabel: isUnauthorizedError(e) ? 'Open Settings' : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'Add repo manually',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _showAddRepoDialog,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Add URL'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (manualRepos.isEmpty)
                        Text(
                          'Paste a GitHub URL (e.g. https://github.com/cesarcastanedo485-png/streamgame) and tap Add URL.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: manualRepos.length,
                          itemBuilder: (context, i) => _RepoCard(
                            repo: manualRepos[i],
                            onLaunch: () => _quickLaunchOnRepo(manualRepos[i].repoUrl),
                            onLaunchWithIntent: () => _pickLaunchIntentAndGo(manualRepos[i].repoUrl),
                            isManual: true,
                            onRemove: () => ref.read(manualReposProvider.notifier).removeUrl(manualRepos[i].repoUrl),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({
    required this.repo,
    required this.onLaunch,
    this.onLaunchWithIntent,
    this.isManual = false,
    this.onRemove,
  });

  final CursorRepository repo;
  final VoidCallback onLaunch;
  final VoidCallback? onLaunchWithIntent;
  final bool isManual;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final dateStr = repo.updatedAt != null
        ? DateFormat.yMMMd().add_jm().format(repo.updatedAt!.toLocal())
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    repo.fullName ?? repo.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isManual && onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onRemove,
                    tooltip: 'Remove',
                  ),
              ],
            ),
            if (isManual)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Added manually',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            if (repo.description != null && repo.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                repo.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              repo.updatedAt != null ? 'Updated: $dateStr' : repo.repoUrl,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onLaunch,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 22),
                    label: const Text('Launch'),
                  ),
                ),
                if (onLaunchWithIntent != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onLaunchWithIntent,
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'Launch with intent (Ask/Plan/Debug)',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
