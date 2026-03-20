import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_errors.dart';
import '../../core/constants.dart';
import '../../providers/agents_provider.dart';
import '../../providers/shell_providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/grouped_agents_list.dart';
import '../../widgets/loading_skeleton.dart';

/// Full list of agents with pull-to-refresh.
class MyAgentsScreen extends ConsumerWidget {
  const MyAgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Agents')),
      body: agentsAsync.when(
        data: (agents) {
          if (agents.isEmpty) {
            return const Center(
              child: Text('No agents yet. Launch one from the Launch tab.'),
            );
          }
          return GroupedAgentsList(
            agents: agents,
            onRefresh: () async => ref.invalidate(agentsListProvider),
            onAgentTap: (a) => Navigator.pushNamed(
              context,
              AppRoutes.agentDetail,
              arguments: a.id,
            ),
          );
        },
        loading: () => const LoadingSkeleton(),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(agentsListProvider),
          onSecondary: isUnauthorizedError(e)
              ? () {
                  ref.read(mainShellTabProvider.notifier).state = 0;
                  ref.read(cloudAgentsSubTabProvider.notifier).state = 3;
                }
              : null,
          secondaryLabel: isUnauthorizedError(e) ? 'Open Settings' : null,
        ),
      ),
    );
  }
}
