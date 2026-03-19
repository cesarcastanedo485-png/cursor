import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backend_mode_provider.dart';

/// Global ribbon: Cursor Cloud vs active private AI.
class ActiveAiBanner extends ConsumerWidget {
  const ActiveAiBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(backendStateProvider);
    final scheme = Theme.of(context).colorScheme;
    final isPrivate = st.mode == AppBackendMode.privateLocal;

    return Material(
      color: isPrivate ? scheme.tertiaryContainer.withValues(alpha: 0.85) : scheme.primaryContainer.withValues(alpha: 0.75),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isPrivate ? Icons.lock_person_rounded : Icons.cloud_rounded,
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active AI',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                          ),
                    ),
                    Text(
                      st.bannerSubtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isPrivate)
                TextButton(
                  onPressed: () => ref.read(backendStateProvider.notifier).switchToCloud(),
                  child: const Text('Use Cloud'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
