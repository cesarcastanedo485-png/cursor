import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/shell_providers.dart';
import '../home/home_screen.dart';
import '../launch/launch_agent_screen.dart';
import '../repos/my_repos_screen.dart';
import '../settings/settings_screen.dart';

/// Cursor Cloud: Home, Launch, Repos, Settings as sub-tabs.
class CloudAgentsShell extends ConsumerWidget {
  const CloudAgentsShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(cloudAgentsSubTabProvider).clamp(0, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _Chip(
                  label: 'Agents',
                  selected: sub == 0,
                  onTap: () => ref.read(cloudAgentsSubTabProvider.notifier).state = 0,
                ),
                _Chip(
                  label: 'Launch',
                  selected: sub == 1,
                  onTap: () => ref.read(cloudAgentsSubTabProvider.notifier).state = 1,
                ),
                _Chip(
                  label: 'Repos',
                  selected: sub == 2,
                  onTap: () => ref.read(cloudAgentsSubTabProvider.notifier).state = 2,
                ),
                _Chip(
                  label: 'Settings',
                  selected: sub == 3,
                  onTap: () => ref.read(cloudAgentsSubTabProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: sub,
            children: const [
              HomeScreen(),
              LaunchAgentScreen(),
              MyReposScreen(),
              SettingsScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
