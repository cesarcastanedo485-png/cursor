import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/agent.dart';

/// Card displaying one agent (status, summary, repo) for list views.
class AgentCard extends StatelessWidget {
  const AgentCard({
    super.key,
    required this.agent,
    this.onTap,
  });

  final Agent agent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: agent.status),
                  const Spacer(),
                  if (agent.createdAt != null)
                    Text(
                      _formatDate(agent.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
              if (agent.repoName != null || agent.repoUrl != null) ...[
                const SizedBox(height: 8),
                Text(
                  agent.repoName ?? agent.repoUrl ?? '',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (agent.summary != null && agent.summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  agent.summary!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    return DateFormat.yMMMd().add_Hm().format(d);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status.toLowerCase() == 'running'
        ? AppColors.statusRunning
        : status.toLowerCase() == 'finished'
            ? AppColors.statusFinished
            : AppColors.statusFailed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
