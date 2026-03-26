import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/dns_lookup.dart';

/// In-app checks: open Cursor API in browser vs DNS + HTTPS from this app.
class ConnectivityDiagnosticsCard extends StatefulWidget {
  const ConnectivityDiagnosticsCard({super.key});

  @override
  State<ConnectivityDiagnosticsCard> createState() =>
      _ConnectivityDiagnosticsCardState();
}

class _ConnectivityDiagnosticsCardState
    extends State<ConnectivityDiagnosticsCard> {
  bool _loading = false;
  String? _result;

  Future<void> _openBrowser() async {
    final uri = Uri.parse(apiBaseUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _runChecks() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    final dns = await dnsLookupApiCursor();
    final http = await httpPingApiCursor();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = '$dns\n\n$http';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Connection check',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'If Test connection fails, compare browser vs this app. '
          'DNS OK + HTTPS OK here means the API key step should work.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openBrowser,
          icon: const Icon(Icons.open_in_browser_rounded),
          label: const Text('Open api.cursor.com in browser'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _loading ? null : _runChecks,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_check_rounded),
          label: Text(_loading ? 'Running…' : 'Run DNS & HTTPS check (this app)'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            _result!,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
