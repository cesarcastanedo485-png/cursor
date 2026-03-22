import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mordechaius_maximus/core/apk_release_log.dart';
import 'package:mordechaius_maximus/providers/preferences_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// After an APK update, shows a one-time "What's new" dialog from [apkReleaseHistory].
class WhatsNewGate extends ConsumerStatefulWidget {
  const WhatsNewGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends ConsumerState<WhatsNewGate> {
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_started || !mounted) return;
    _started = true;
    final prefs = await ref.read(preferencesProvider.future);
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    if (build <= prefs.lastWhatsNewAcknowledgedBuild) return;
    if (!mounted) return;

    final entry = apkReleaseEntryForInstalledBuild(build);
    if (!mounted) return;

    if (entry == null) {
      await prefs.setLastWhatsNewAcknowledgedBuild(build);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("What's new — ${entry.apkLabel}"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.released.isNotEmpty && !entry.released.startsWith('('))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    entry.released,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              ...entry.changes.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await prefs.setLastWhatsNewAcknowledgedBuild(build);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
