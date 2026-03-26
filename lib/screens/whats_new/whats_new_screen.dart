import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/apk_release_log.dart';
import '../../core/app_strings.dart';

/// Modal showing what's new when the user has upgraded to a newer app version.
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({
    super.key,
    required this.entries,
    required this.onDismiss,
  });

  final List<ApkReleaseEntry> entries;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("What's New"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  AppStrings.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s new in this update:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                ...entries.map((e) => _ReleaseCard(entry: e)),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: onDismiss,
                child: const Text('Got it'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.entry});

  final ApkReleaseEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.apkLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  entry.released,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in entry.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: theme.textTheme.bodyMedium),
                    Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Returns ApkReleaseEntry items for versions newer than lastSeenVersion.
List<ApkReleaseEntry> getNewerReleaseEntries(
  String? lastSeenVersion,
  int currentBuildNumber,
) {
  if (lastSeenVersion == null || lastSeenVersion.isEmpty) {
    return [];
  }
  int lastBuild;
  try {
    final parts = lastSeenVersion.split('+');
    lastBuild = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
  } catch (_) {
    return [];
  }
  if (currentBuildNumber <= lastBuild) {
    return [];
  }
  return apkReleaseHistory
      .where((e) => e.buildNumber > lastBuild && e.buildNumber <= currentBuildNumber)
      .toList();
}

/// Check if we should show What's New: current build > last seen build.
Future<bool> shouldShowWhatsNew(
  PackageInfo info,
  String? lastSeenVersion,
) async {
  if (lastSeenVersion == null || lastSeenVersion.isEmpty) {
    return false;
  }
  int lastBuild;
  try {
    final parts = lastSeenVersion.split('+');
    lastBuild = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
  } catch (_) {
    return false;
  }
  final currentBuild = int.tryParse(info.buildNumber) ?? 0;
  return currentBuild > lastBuild;
}
