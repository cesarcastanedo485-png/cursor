import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api_errors.dart';
import '../../data/models/cursor_repository.dart';
import '../../providers/repositories_provider.dart';
import '../../providers/shell_providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

/// Searchable list of GitHub repos from Cursor API.
class MyReposScreen extends ConsumerStatefulWidget {
  const MyReposScreen({super.key});

  @override
  ConsumerState<MyReposScreen> createState() => _MyReposScreenState();
}

class _MyReposScreenState extends ConsumerState<MyReposScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _launchOnRepo(String url) {
    ref.read(launchRepoPrefillProvider.notifier).state = url;
    ref.read(mainShellTabProvider.notifier).state = 0;
    ref.read(cloudAgentsSubTabProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(repositoriesProvider);
    final q = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Repos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(repositoriesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
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
              data: (repos) {
                final filtered = q.isEmpty
                    ? repos
                    : repos.where((r) {
                        final n = '${r.name} ${r.fullName} ${r.description}'.toLowerCase();
                        return n.contains(q);
                      }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      repos.isEmpty ? 'No repositories returned. Connect GitHub in Cursor.' : 'No matches',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(repositoriesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _RepoCard(
                      repo: filtered[i],
                      onLaunch: () => _launchOnRepo(filtered[i].repoUrl),
                    ),
                  ),
                );
              },
              loading: () => const LoadingSkeleton(),
              error: (e, _) => ErrorView(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(repositoriesProvider),
                onSecondary: isUnauthorizedError(e)
                    ? () {
                        ref.read(mainShellTabProvider.notifier).state = 0;
                        ref.read(cloudAgentsSubTabProvider.notifier).state = 3;
                      }
                    : null,
                secondaryLabel: isUnauthorizedError(e) ? 'Open Settings' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({required this.repo, required this.onLaunch});

  final CursorRepository repo;
  final VoidCallback onLaunch;

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
            Text(
              repo.fullName ?? repo.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              'Updated: $dateStr',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onLaunch,
              icon: const Icon(Icons.rocket_launch_rounded, size: 22),
              label: const Text('Launch Agent on this Repo'),
            ),
          ],
        ),
      ),
    );
  }
}
