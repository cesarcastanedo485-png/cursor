import 'package:flutter/material.dart';
import '../data/models/agent.dart';
import 'agent_card.dart';

/// Repository-grouped agents list with pull-to-refresh.
class GroupedAgentsList extends StatelessWidget {
  const GroupedAgentsList({
    super.key,
    required this.agents,
    required this.onRefresh,
    required this.onAgentTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.leadingWidgets = const [],
  });

  final List<Agent> agents;
  final Future<void> Function() onRefresh;
  final void Function(Agent) onAgentTap;
  final EdgeInsetsGeometry padding;
  final List<Widget> leadingWidgets;

  @override
  Widget build(BuildContext context) {
    final groups = _buildRepoGroups(agents);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: padding,
        children: [
          ...leadingWidgets,
          for (final group in groups) ...[
            _GroupHeader(
              label: group.label,
              count: group.agents.length,
              prCount: group.agents.where((a) => (a.pullRequestUrl ?? '').trim().isNotEmpty).length,
            ),
            const SizedBox(height: 8),
            ...group.agents.map(
              (agent) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AgentCard(
                  agent: agent,
                  onTap: () => onAgentTap(agent),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

List<_RepoGroup> _buildRepoGroups(List<Agent> agents) {
  final grouped = <String, _RepoGroup>{};

  for (final agent in agents) {
    final key = _repoKey(agent);
    final label = _repoLabel(agent);
    final sortTime = _activityTime(agent);
    final existing = grouped[key];
    if (existing == null) {
      grouped[key] = _RepoGroup(
        label: label,
        agents: [agent],
        latestActivity: sortTime,
        isUnknownRepo: key == _unknownRepoKey,
      );
      continue;
    }

    existing.agents.add(agent);
    if (_isBetterLabel(current: existing.label, candidate: label)) {
      existing.label = label;
    }
    if (sortTime.isAfter(existing.latestActivity)) {
      existing.latestActivity = sortTime;
    }
  }

  final groups = grouped.values.toList();
  for (final group in groups) {
    group.agents.sort((a, b) => _activityTime(b).compareTo(_activityTime(a)));
  }
  groups.sort((a, b) {
    if (a.isUnknownRepo != b.isUnknownRepo) return a.isUnknownRepo ? 1 : -1;
    return b.latestActivity.compareTo(a.latestActivity);
  });
  return groups;
}

DateTime _activityTime(Agent agent) {
  return agent.updatedAt ??
      agent.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

const String _unknownRepoKey = '__unknown_repo__';

String _repoKey(Agent agent) {
  final fromUrl = _ownerRepoFromUrl(agent.repoUrl);
  if (fromUrl != null) return fromUrl.toLowerCase();
  final repoName = (agent.repoName ?? '').trim();
  if (repoName.isNotEmpty) return repoName.toLowerCase();
  return _unknownRepoKey;
}

String _repoLabel(Agent agent) {
  final repoName = (agent.repoName ?? '').trim();
  if (repoName.isNotEmpty) return repoName;
  final fromUrl = _ownerRepoFromUrl(agent.repoUrl);
  if (fromUrl != null) return fromUrl;
  return 'No repository detected';
}

String? _ownerRepoFromUrl(String? rawUrl) {
  final input = (rawUrl ?? '').trim();
  if (input.isEmpty) return null;
  final uri = Uri.tryParse(input);
  if (uri == null) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2) return null;
  final owner = segments[0];
  final repo = segments[1].replaceAll(RegExp(r'\.git$'), '');
  if (owner.isEmpty || repo.isEmpty) return null;
  return '$owner/$repo';
}

bool _isBetterLabel({required String current, required String candidate}) {
  if (current == 'No repository detected' && candidate != current) return true;
  if (candidate.contains('/') && !current.contains('/')) return true;
  return false;
}

class _RepoGroup {
  _RepoGroup({
    required this.label,
    required this.agents,
    required this.latestActivity,
    required this.isUnknownRepo,
  });

  String label;
  final List<Agent> agents;
  DateTime latestActivity;
  final bool isUnknownRepo;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.prCount,
  });

  final String label;
  final int count;
  final int prCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '($count)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (prCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$prCount PR${prCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
