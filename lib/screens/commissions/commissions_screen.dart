import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/shell_providers.dart';

/// Commissions tab: WebView to Mordecai or placeholder with setup links.
class CommissionsScreen extends ConsumerWidget {
  const CommissionsScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesProvider);
    return prefsAsync.when(
      data: (prefs) {
        final url = prefs.mordecaiCommissionsUrl.trim();
        if (url.isNotEmpty) {
          return _CommissionsWebView(initialUrl: url);
        }
        return _CommissionsPlaceholder(
          onOpenReleases: () => _openUrl(context, githubReleasesUrl),
          onOpenSettings: () {
            ref.read(mainShellTabProvider.notifier).state = 0;
            ref.read(cloudAgentsSubTabProvider.notifier).state = 3;
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _CommissionsPlaceholder(
        onOpenReleases: () => _openUrl(context, githubReleasesUrl),
        onOpenSettings: () {
          ref.read(mainShellTabProvider.notifier).state = 0;
          ref.read(cloudAgentsSubTabProvider.notifier).state = 3;
        },
      ),
    );
  }
}

class _CommissionsWebView extends StatefulWidget {
  const _CommissionsWebView({required this.initialUrl});

  final String initialUrl;

  @override
  State<_CommissionsWebView> createState() => _CommissionsWebViewState();
}

class _CommissionsWebViewState extends State<_CommissionsWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

class _CommissionsPlaceholder extends StatelessWidget {
  const _CommissionsPlaceholder({
    required this.onOpenReleases,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenReleases;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.handyman_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Commissions',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Build websites with phased workflows. Set Mordecai URL in Settings (Cloud Agents → Settings), or download the APK.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenReleases,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download APK (Releases)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
