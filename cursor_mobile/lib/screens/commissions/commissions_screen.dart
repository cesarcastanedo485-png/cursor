import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../providers/bridge_task_provider.dart';
import '../../../providers/preferences_provider.dart';
import '../../../services/mordecai_health_service.dart';

Future<bool> _saveMordecaiUrlFromCommissionsTab(
  BuildContext context,
  WidgetRef ref,
  String raw,
) async {
  final validation = MordecaiHealthService.validateForCommissions(
    raw.trim(),
    assumeMobileDevice: true,
  );
  if (!validation.isValid) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(validation.error ?? 'Invalid Mordecai URL.')),
    );
    return false;
  }
  if (validation.hasWarning) {
    final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mordecai URL warning'),
            content: Text(validation.warning!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save anyway'),
              ),
            ],
          ),
        ) ??
        false;
    if (!proceed) return false;
  }

  try {
    final prefs = await ref.read(preferencesProvider.future);
    await prefs.setMordecaiCommissionsUrl(validation.normalizedUrl);
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not save Mordecai URL: $e')),
    );
    return false;
  }

  ref.invalidate(preferencesProvider);
  ref.invalidate(bridgeTaskServiceProvider);
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Mordecai URL saved. Commissions will load it.'),
    ),
  );
  return true;
}

Future<void> _showChangeMordecaiUrlDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  String initial = '';
  try {
    final prefs = await ref.read(preferencesProvider.future);
    initial = prefs.mordecaiCommissionsUrl;
  } catch (_) {}

  if (!context.mounted) return;
  final tc = TextEditingController(text: initial);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Change Mordecai URL'),
      content: TextField(
        controller: tc,
        decoration: const InputDecoration(
          labelText: 'Public URL',
          hintText: 'https://your-tunnel.trycloudflare.com',
          helperText: 'HTTPS only on phone. Use your tunnel or public base URL.',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
        autocorrect: false,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final navigator = Navigator.of(ctx);
            final saved = await _saveMordecaiUrlFromCommissionsTab(
              context,
              ref,
              tc.text,
            );
            if (saved && navigator.canPop()) navigator.pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  tc.dispose();
}

/// Commissions tab: health check + WebView to Mordecai, or in-tab URL registration.
class CommissionsScreen extends ConsumerWidget {
  const CommissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesProvider);
    return prefsAsync.when(
      data: (prefs) {
        final url = prefs.mordecaiCommissionsUrl.trim();
        if (url.isNotEmpty) {
          return _CommissionsPanel(
            key: ValueKey<String>(url),
            rawUrl: url,
            onChangeMordecaiUrl: () => _showChangeMordecaiUrlDialog(context, ref),
          );
        }
        return const _CommissionsUrlRegistration();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _CommissionsUrlRegistration(loadError: '$e'),
    );
  }
}

enum _HealthPhase { checking, ready, offline }

/// Health gate then WebView; [rawUrl] is as stored in Settings (may omit scheme).
class _CommissionsPanel extends StatefulWidget {
  const _CommissionsPanel({
    super.key,
    required this.rawUrl,
    required this.onChangeMordecaiUrl,
  });

  final String rawUrl;
  final VoidCallback onChangeMordecaiUrl;

  @override
  State<_CommissionsPanel> createState() => _CommissionsPanelState();
}

class _CommissionsPanelState extends State<_CommissionsPanel> {
  static const Duration _loadWatchdogDuration = Duration(seconds: 45);
  static const Duration _domProbeDelay = Duration(milliseconds: 650);

  /// Confirms the Mordecai shell rendered: stable markers even if headings copy changes.
  static const String _domProbeJs = r'''(function() {
  try {
    var el = document.documentElement;
    if (el && el.getAttribute("data-mordecai-shell") === "1") return 1;
    var meta = document.querySelector('meta[name="application-name"]');
    var ac = meta && meta.getAttribute("content");
    if (ac && ac.indexOf("Mordecai") >= 0) return 1;
    if (document.querySelector(".mordecai-title")) return 1;
    if (document.getElementById("commissions-view")) return 1;
    if (document.querySelector('script[src*="mordecai.js"]')) return 1;
    if (document.body && document.body.classList.contains("mordecai-page")) return 1;
    var b = document.body;
    if (!b) return 0;
    var text = (b.innerText || "").trim();
    return text.length > 80 ? 1 : 0;
  } catch (e) { return 0; }
})()''';

  _HealthPhase _phase = _HealthPhase.checking;
  bool _forceWebView = false;
  late final WebViewController _controller;
  late final String _normalizedUrl;
  String? _webError;
  String? _webErrorCategory;
  String? _webErrorUrl;
  bool _webLoading = true;
  int _webProgress = 0;
  Timer? _loadWatchdog;
  /// Bumps on each navigation so stale [onPageFinished] probes cannot overwrite UI.
  int _navEpoch = 0;

  @override
  void dispose() {
    _cancelLoadWatchdog();
    super.dispose();
  }

  void _cancelLoadWatchdog() {
    _loadWatchdog?.cancel();
    _loadWatchdog = null;
  }

  void _startLoadWatchdog() {
    _cancelLoadWatchdog();
    _loadWatchdog = Timer(_loadWatchdogDuration, () {
      if (!mounted || !_webLoading) return;
      setState(() {
        _webLoading = false;
        _webError =
            'Page took too long to load. Quick tunnels get a new URL when cloudflared restarts — paste the fresh trycloudflare link via Change Mordecai URL, confirm npm start is running, then retry.';
        _webErrorCategory = 'Load timeout';
        _webErrorUrl = _normalizedUrl;
      });
    });
  }

  bool _domProbeLooksLikeMordecai(Object? raw) {
    if (raw is bool) return raw;
    if (raw is int) return raw == 1;
    if (raw is double) return raw == 1.0;
    if (raw is String) {
      final s = raw.trim();
      return s == '1' || s == '"1"' || s == "true";
    }
    return false;
  }

  Future<bool> _runDomProbeOnce() async {
    try {
      final Object raw = await _controller.runJavaScriptReturningResult(_domProbeJs);
      return _domProbeLooksLikeMordecai(raw);
    } catch (_) {
      return false;
    }
  }

  Future<void> _probeRenderedMordecaiPage(int epoch) async {
    await Future<void>.delayed(_domProbeDelay);
    if (!mounted || epoch != _navEpoch || _webError != null) return;

    if (await _runDomProbeOnce()) {
      if (!mounted || epoch != _navEpoch) return;
      setState(() => _webLoading = false);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || epoch != _navEpoch || _webError != null) return;

    if (await _runDomProbeOnce()) {
      if (!mounted || epoch != _navEpoch) return;
      setState(() => _webLoading = false);
      return;
    }

    if (!mounted || epoch != _navEpoch) return;
    setState(() {
      _webLoading = false;
      _webError =
          'The page loaded but Mordecai’s UI did not appear. Typical causes: tunnel or bot checks that block in-app WebViews, expired tunnel URL, or stale cached scripts. Try Open in browser; in the phone browser use “clear site data” for this host; then paste a fresh HTTPS tunnel URL (Change Mordecai URL).';
      _webErrorCategory = 'Blank or incomplete page';
      _webErrorUrl = _normalizedUrl;
    });
  }

  @override
  void initState() {
    super.initState();
    final validation = MordecaiHealthService.validateForCommissions(widget.rawUrl);
    _normalizedUrl = validation.normalizedUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            _navEpoch++;
            _startLoadWatchdog();
            setState(() {
              _webLoading = true;
              _webProgress = 0;
              _webError = null;
              _webErrorCategory = null;
              _webErrorUrl = null;
            });
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _webProgress = progress;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            final epoch = _navEpoch;
            _cancelLoadWatchdog();
            setState(() {
              _webProgress = 100;
            });
            _probeRenderedMordecaiPage(epoch);
          },
          onHttpError: (HttpResponseError error) {
            if (!mounted) return;
            _cancelLoadWatchdog();
            final code = error.response?.statusCode ?? 0;
            final uri = error.request?.uri.toString() ?? _normalizedUrl;
            setState(() {
              _webLoading = false;
              _webErrorCategory = 'HTTP $code';
              _webError = code > 0
                  ? 'Server returned HTTP $code for the main document. Confirm the Mordecai base URL (your tunnel) matches the machine where `npm start` is running.'
                  : 'HTTP error while loading the main document.';
              _webErrorUrl = uri;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            _cancelLoadWatchdog();
            if (error.isForMainFrame == false) return;
            final details = _classifyWebError(
              description: error.description,
              errorCode: error.errorCode,
            );
            setState(() {
              _webLoading = false;
              _webError = details.$1;
              _webErrorCategory = details.$2;
              _webErrorUrl = error.url ?? _normalizedUrl;
            });
          },
        ),
      );
    if (validation.isValid) {
      _controller.loadRequest(Uri.parse(_normalizedUrl));
    } else {
      _webLoading = false;
      _webError = validation.error ?? 'Invalid URL';
      _webErrorCategory = 'Invalid URL';
      _webErrorUrl = _normalizedUrl.isEmpty ? widget.rawUrl : _normalizedUrl;
      _phase = _HealthPhase.offline;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _runHealthCheck());
  }

  Future<void> _runHealthCheck() async {
    final validation = MordecaiHealthService.validateForCommissions(widget.rawUrl);
    if (!validation.isValid) {
      if (!mounted) return;
      setState(() {
        _phase = _HealthPhase.offline;
        _forceWebView = false;
        _webError = validation.error ?? 'Invalid URL';
        _webErrorCategory = 'Invalid URL';
        _webErrorUrl = validation.normalizedUrl.isEmpty
            ? widget.rawUrl
            : validation.normalizedUrl;
        _webLoading = false;
      });
      return;
    }
    setState(() {
      _phase = _HealthPhase.checking;
      _forceWebView = false;
    });
    final ok = await MordecaiHealthService.isReachable(widget.rawUrl);
    if (!mounted) return;
    setState(() {
      _phase = ok ? _HealthPhase.ready : _HealthPhase.offline;
    });
  }

  Future<void> _openExternal() async {
    final target = _webErrorUrl ?? _normalizedUrl;
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _retryWebApp() async {
    setState(() {
      _webError = null;
      _webErrorCategory = null;
      _webErrorUrl = null;
      _webLoading = true;
      _webProgress = 0;
    });
    await _runHealthCheck();
    final target = Uri.tryParse(_normalizedUrl);
    if (target != null) {
      await _controller.loadRequest(target);
    }
  }

  (String, String) _classifyWebError({
    required String description,
    required int errorCode,
  }) {
    final d = description.toLowerCase();
    if (d.contains('cleartext') || d.contains('not permitted')) {
      return (
        'Cleartext HTTP was blocked by mobile WebView. Use an HTTPS tunnel URL.',
        'Cleartext blocked',
      );
    }
    if (d.contains('ssl') || d.contains('certificate') || d.contains('cert_')) {
      return (
        'SSL/TLS handshake failed. Check tunnel certificate and ensure URL is valid.',
        'SSL error',
      );
    }
    if (d.contains('host lookup') ||
        d.contains('name not resolved') ||
        d.contains('dns')) {
      return (
        'Host could not be resolved. Tunnel URL may have changed or expired.',
        'Host unreachable',
      );
    }
    if (d.contains('timed out') ||
        d.contains('connection') ||
        d.contains('refused') ||
        d.contains('internet disconnected') ||
        errorCode == -2 ||
        errorCode == -6 ||
        errorCode == -7) {
      return (
        'Network connection failed. Verify server is running and tunnel is active.',
        'Network error',
      );
    }
    return (
      'Web app load failed. Verify Mordecai URL and retry.',
      'Web load error',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_phase == _HealthPhase.checking && !_forceWebView) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Checking Mordecai server…',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _normalizedUrl,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_phase == _HealthPhase.offline && !_forceWebView) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                'Cannot reach Mordecai',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Start the server (npm start), use your tunnel URL (HTTPS on phone), '
                'then tap Retry. Health checks call /api/commissions/health or /health.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(
                _normalizedUrl,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_webError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _webError!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _runHealthCheck,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _forceWebView = true),
                child: const Text('Open web app anyway'),
              ),
              TextButton(
                onPressed: _openExternal,
                child: const Text('Open in browser'),
              ),
              TextButton(
                onPressed: widget.onChangeMordecaiUrl,
                child: const Text('Change Mordecai URL'),
              ),
            ],
          ),
        ),
      );
    }

    final skippedCheck =
        _forceWebView && _phase == _HealthPhase.offline;
    final bannerBg = skippedCheck ? scheme.tertiaryContainer : scheme.primaryContainer;
    final bannerFg = skippedCheck ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;

    final hasWebError = _webError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: bannerBg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  skippedCheck ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: bannerFg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skippedCheck
                            ? 'Opened without health check'
                            : 'Mordecai is reachable',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: bannerFg,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        skippedCheck
                            ? 'The server did not respond to /health. Fix URL or tunnel, then tap refresh.'
                            : 'Mordecai answered the health check. Commissions workflow is ready below.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: bannerFg.withValues(alpha: 0.9),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Re-check server',
                  onPressed: _runHealthCheck,
                  icon: Icon(Icons.refresh_rounded, color: bannerFg),
                ),
              ],
            ),
          ),
        ),
        if (_webLoading && !hasWebError)
          LinearProgressIndicator(
            value: _webProgress > 0 && _webProgress < 100
                ? _webProgress / 100
                : null,
          ),
        Expanded(
          child: hasWebError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 54,
                          color: scheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _webErrorCategory ?? 'Web load error',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _webError ?? 'Unable to load Commissions web app.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          _webErrorUrl ?? _normalizedUrl,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _retryWebApp,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _openExternal,
                          child: const Text('Open in browser'),
                        ),
                        TextButton(
                          onPressed: widget.onChangeMordecaiUrl,
                          child: const Text('Change Mordecai URL'),
                        ),
                      ],
                    ),
                  ),
                )
              : WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}

class _CommissionsUrlRegistration extends ConsumerStatefulWidget {
  const _CommissionsUrlRegistration({this.loadError});

  /// When [preferencesProvider] failed, shows a short message; save still attempts after invalidate.
  final String? loadError;

  @override
  ConsumerState<_CommissionsUrlRegistration> createState() =>
      _CommissionsUrlRegistrationState();
}

class _CommissionsUrlRegistrationState extends ConsumerState<_CommissionsUrlRegistration> {
  final _url = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.loadError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final prefs = await ref.read(preferencesProvider.future);
          if (mounted) _url.text = prefs.mordecaiCommissionsUrl;
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not load saved URL. Enter it below.'),
              ),
            );
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveMordecaiUrlFromCommissionsTab(context, ref, _url.text);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.handyman_rounded, size: 64, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Commissions',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your Mordecai public URL (same as Cloud Agents → Settings). '
                    'The app will verify the server, then open the phased commissions workflow.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.loadError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Could not load saved settings. Enter your URL below or open Settings from another tab.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.loadError!,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _url,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Public URL',
                      hintText: 'https://your-tunnel.trycloudflare.com',
                      helperText:
                          'HTTPS only on phone. Tunnel or host where `npm start` runs Mordecai.',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save URL'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
