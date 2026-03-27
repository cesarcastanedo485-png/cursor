import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/app_strings.dart';
import '../../../data/models/agent.dart';
import '../../../core/constants.dart';
import '../../../providers/agents_provider.dart';
import '../../../core/api_errors.dart';
import '../../../providers/cache_provider.dart';
import '../../../providers/home_agent_filter_provider.dart';
import '../../../providers/shell_providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/grouped_agents_list.dart';
import '../../widgets/loading_skeleton.dart';

/// Dashboard: recent agents (from API or cache if offline).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsListProvider);
    final cacheAsync = ref.watch(cachedAgentsProvider);
    final cacheTs = ref.watch(cacheTimestampProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            tooltip: 'All agents',
            icon: const Icon(Icons.list_alt_rounded),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.agents),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HomeFilterChips(),
          Expanded(
            child: agentsAsync.when(
              data: (agents) {
                if (agents.isEmpty) {
                  return _empty(context, ref, cacheAsync, cacheTs);
                }
                final filter = ref.watch(homeAgentFilterProvider);
                final filtered = filterAgentsForHome(agents, filter);
                if (filtered.isEmpty) {
                  return _emptyFilter(context, ref, filter);
                }
                return GroupedAgentsList(
                  agents: filtered,
                  onRefresh: () async => ref.invalidate(agentsListProvider),
                  onAgentTap: (a) => Navigator.pushNamed(
                    context,
                    AppRoutes.agentDetail,
                    arguments: a.id,
                  ),
                );
              },
              loading: () => _loadingOrCached(context, ref, cacheAsync, cacheTs),
              error: (e, _) => _errorOrCached(context, ref, e, cacheAsync, cacheTs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFilter(BuildContext context, WidgetRef ref, HomeAgentFilter filter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No agents match “${_filterLabel(filter)}”',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(homeAgentFilterProvider.notifier).state = HomeAgentFilter.all,
              child: const Text('Show all'),
            ),
          ],
        ),
      ),
    );
  }

  static String _filterLabel(HomeAgentFilter f) {
    switch (f) {
      case HomeAgentFilter.all:
        return 'All';
      case HomeAgentFilter.active:
        return 'Active';
      case HomeAgentFilter.finished:
        return 'Finished';
      case HomeAgentFilter.failed:
        return 'Failed';
    }
  }

  Widget _empty(BuildContext context, WidgetRef ref, AsyncValue<List<Agent>> cacheAsync, AsyncValue<DateTime?> cacheTs) {
    return cacheAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.smart_toy_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'No agents yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Launch an agent from the Launch tab',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }
        return _listFromCache(context, ref, list, cacheTs, offlineSnapshot: false);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No agents yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Launch an agent from the Launch tab',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _listFromCache(
    BuildContext context,
    WidgetRef ref,
    List<Agent> cached,
    AsyncValue<DateTime?> cacheTs, {
    bool offlineSnapshot = false,
  }) {
    final filter = ref.watch(homeAgentFilterProvider);
    final filtered = filterAgentsForHome(cached, filter);
    if (filtered.isEmpty && cached.isNotEmpty) {
      return _emptyFilter(context, ref, filter);
    }
    final leading = <Widget>[
      if (offlineSnapshot)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              label: const Text('Offline snapshot'),
            ),
          ),
        ),
      if (cacheTs.value != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Last updated: ${DateFormat.yMMMd().add_jm().format(cacheTs.value!.toLocal())}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
    ];
    return GroupedAgentsList(
      agents: filtered,
      onRefresh: () async => ref.invalidate(agentsListProvider),
      onAgentTap: (a) => Navigator.pushNamed(
        context,
        AppRoutes.agentDetail,
        arguments: a.id,
      ),
      padding: const EdgeInsets.all(16),
      leadingWidgets: leading,
    );
  }

  Widget _loadingOrCached(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Agent>> cacheAsync,
    AsyncValue<DateTime?> cacheTs,
  ) {
    return cacheAsync.when(
      data: (list) {
        if (list.isEmpty) return const LoadingSkeleton();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            Expanded(child: _listFromCache(context, ref, list, cacheTs, offlineSnapshot: false)),
          ],
        );
      },
      loading: () => const LoadingSkeleton(),
      error: (_, __) => const LoadingSkeleton(),
    );
  }

  Widget _errorOrCached(
    BuildContext context,
    WidgetRef ref,
    Object e,
    AsyncValue<List<Agent>> cacheAsync,
    AsyncValue<DateTime?> cacheTs,
  ) {
    final openSettings = isUnauthorizedError(e)
        ? () {
            ref.read(mainShellTabProvider.notifier).state = 0;
            ref.read(cloudAgentsSubTabProvider.notifier).state = 3;
          }
        : null;
    return cacheAsync.when(
      data: (list) {
        return Column(
          children: [
            ErrorView(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(agentsListProvider),
              onSecondary: openSettings,
              secondaryLabel: openSettings != null ? 'Open Settings' : null,
            ),
            if (list.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Showing cached agents',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Expanded(child: _listFromCache(context, ref, list, cacheTs, offlineSnapshot: true)),
            ],
          ],
        );
      },
      loading: () => ErrorView(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(agentsListProvider),
        onSecondary: openSettings,
        secondaryLabel: openSettings != null ? 'Open Settings' : null,
      ),
      error: (_, __) => ErrorView(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(agentsListProvider),
        onSecondary: openSettings,
        secondaryLabel: openSettings != null ? 'Open Settings' : null,
      ),
    );
  }
}

class _HomeFilterChips extends ConsumerWidget {
  const _HomeFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(homeAgentFilterProvider);
    Widget chip(HomeAgentFilter value, String label) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: f == value,
          onSelected: (_) => ref.read(homeAgentFilterProvider.notifier).state = value,
        ),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            chip(HomeAgentFilter.all, 'All'),
            chip(HomeAgentFilter.active, 'Active'),
            chip(HomeAgentFilter.finished, 'Finished'),
            chip(HomeAgentFilter.failed, 'Failed'),
          ],
        ),
      ),
    );
  }
}
