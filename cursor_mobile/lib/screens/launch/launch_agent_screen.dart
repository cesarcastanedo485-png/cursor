import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/agent_intent.dart';
import '../../../core/constants.dart';
import '../../../core/launch_routing_policy.dart';
import '../../../data/models/launch_request.dart';
import '../../../providers/agents_provider.dart';
import '../../../providers/bridge_task_provider.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/shell_providers.dart';
import '../../../services/bridge_task_service.dart';
import '../../widgets/error_view.dart';

/// Launch agent: repo URL, prompt, options, POST /v0/agents.
class LaunchAgentScreen extends ConsumerStatefulWidget {
  const LaunchAgentScreen({super.key});

  @override
  ConsumerState<LaunchAgentScreen> createState() => _LaunchAgentScreenState();
}

class _LaunchAgentScreenState extends ConsumerState<LaunchAgentScreen> {
  final _repoController = TextEditingController();
  final _branchController = TextEditingController();
  final _promptController = TextEditingController();
  String _model = 'auto';
  AgentIntent _intent = AgentIntent.normal;
  bool _autoCreatePr = false;
  bool _useDesktop = true;
  String? _imagePath;
  bool _launching = false;
  String? _launchError;
  String? _launchedAgentId;
  String? _appliedPrefill;
  String? _launchRouteNote;
  int? _lastLaunchAtMs;

  void _clearLaunchDraft() {
    _promptController.clear();
    setState(() {
      _intent = AgentIntent.normal;
      _imagePath = null;
      _launchError = null;
      _launchedAgentId = null;
    });
  }

  String _formatLaunchError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final body = data == null
          ? (e.message ?? 'No response body')
          : (data is String ? data : jsonEncode(data));
      return 'Cursor launch failed (HTTP $code).\n$body';
    }
    return e.toString();
  }

  // auto = Cursor's default (cost-efficient). Avoid expensive models for simple requests.
  static const _models = ['auto', 'claude-4-sonnet', 'claude-4-opus', 'gpt-4o-mini'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDesktopPref());
  }

  Future<void> _loadDesktopPref() async {
    try {
      final prefs = await ref.read(preferencesProvider.future);
      if (mounted) setState(() => _useDesktop = prefs.preferDesktopBridge);
    } catch (_) {}
  }

  @override
  void dispose() {
    _repoController.dispose();
    _branchController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool fromCamera) async {
    final picker = ImagePicker();
    final x = fromCamera
        ? await picker.pickImage(source: ImageSource.camera)
        : await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _imagePath = x.path);
  }

  Future<String?> _imageToBase64() async {
    if (_imagePath == null) return null;
    final file = File(_imagePath!);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  String? _normalizeRepoUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;
    final withScheme = input.startsWith('http://') || input.startsWith('https://')
        ? input
        : 'https://github.com/$input';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;

    // Accept owner/repo only from github.com URLs.
    final isGithub = uri.host.toLowerCase().contains('github.com');
    if (!isGithub) return null;

    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return null;
    final owner = segs[0];
    final repo = segs[1].replaceAll(RegExp(r'\.git$'), '');
    if (owner.isEmpty || repo.isEmpty) return null;
    return 'https://github.com/$owner/$repo';
  }

  Future<void> _launch() async {
    final repo = _normalizeRepoUrl(_repoController.text);
    final prompt = _promptController.text.trim();
    if (repo == null) {
      setState(() => _launchError = 'Enter a valid GitHub repo URL (owner/repo or https://github.com/owner/repo)');
      return;
    }
    if (prompt.isEmpty) {
      setState(() => _launchError = 'Enter a prompt');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (LaunchRoutingPolicy.isCooldownBlocked(
      lastLaunchAtMs: _lastLaunchAtMs,
      nowMs: now,
    )) {
      setState(
        () => _launchError =
            'Please wait a second before launching again (cooldown).',
      );
      return;
    }
    setState(() {
      _launching = true;
      _launchError = null;
      _launchedAgentId = null;
      _launchRouteNote = null;
      _repoController.text = repo;
    });
    _lastLaunchAtMs = now;
    final branch = _branchController.text.trim();
    final effectivePrompt = buildPromptForIntent(_intent, prompt);

    // Use desktop bridge when configured and selected (saves Cloud API tokens)
    final prefs = await ref.read(preferencesProvider.future);
    final useDesktop = _useDesktop &&
        prefs.mordecaiCommissionsUrl.trim().isNotEmpty &&
        prefs.preferDesktopBridge;

    final bridgeService = useDesktop
        ? await ref.read(bridgeTaskServiceProvider.future)
        : null;
    final readiness = bridgeService != null
        ? await bridgeService.checkReadiness()
        : const BridgeReadiness(ready: false, reason: 'bridge_not_configured');
    final decision = LaunchRoutingPolicy.decide(
      preferDesktop: useDesktop,
      hasBridgeService: bridgeService != null,
      bridgeReady: readiness.ready,
      lastLaunchAtMs: null,
      nowMs: now,
    );

    if (decision.path == LaunchRoutePath.desktop && bridgeService != null) {
      final fcmToken = await ref.read(fcmTokenProvider.future);
      BridgeTaskResult? result;
      for (var i = 0; i < LaunchRoutingPolicy.desktopRetryBudget; i++) {
        result = await bridgeService.submitTask(
          prompt: effectivePrompt,
          repoUrl: repo,
          branch: branch.isEmpty ? null : branch,
          intent: _intent.name,
          fcmToken: fcmToken,
        );
        if (result.taskId != null) break;
      }
      if (!mounted) return;
      if (result?.taskId != null) {
        await bridgeService.reportLaunchRoute(path: 'desktop');
        if (!mounted) return;
        setState(() {
          _launching = false;
          _promptController.clear();
          _imagePath = null;
          _launchRouteNote = 'Desktop bridge path used (cloud API skipped).';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Task sent to desktop. Open Cursor to run. You\'ll get a notification when done.',
            ),
          ),
        );
        return;
      }

      // Desktop was preferred but failed after retry budget: auto-fallback.
      final fallbackReason = (result?.error ?? 'bridge_submit_failed')
          .replaceAll('\n', ' ')
          .trim();
      await bridgeService.reportLaunchRoute(
        path: 'cloud_fallback',
        fallbackReason: fallbackReason,
      );
      setState(() {
        _launchRouteNote =
            'Desktop bridge unavailable; auto-fallback to cloud API.';
      });
    } else if (bridgeService != null) {
      await bridgeService.reportLaunchRoute(
        path: 'cloud_fallback',
        fallbackReason: readiness.reason,
      );
      setState(() {
        _launchRouteNote =
            'Desktop bridge not ready (${readiness.reason}); auto-fallback to cloud API.';
      });
    }

    // Fall back to Cloud API
    final imageB64 = await _imageToBase64();
    final request = LaunchRequest(
      repoUrl: repo,
      prompt: effectivePrompt,
      ref: branch.isEmpty ? null : branch,
      branchName: branch.isEmpty ? null : branch,
      model: _model,
      autoCreatePr: _autoCreatePr,
      imageBase64: imageB64,
    );
    try {
      final agentId = await ref.read(launchAgentProvider(request).future);
      if (!mounted) return;
      setState(() {
        _launching = false;
        _launchedAgentId = agentId;
        _promptController.clear();
        _imagePath = null;
        _launchRouteNote ??= 'Cloud API path used.';
      });
      if (agentId != null && agentId.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.agentDetail, arguments: agentId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _launching = false;
        _launchError = _formatLaunchError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(launchTabResetCounterProvider, (previous, next) {
      if (previous != null && next > previous && mounted) {
        _clearLaunchDraft();
      }
    });

    final pre = ref.watch(launchRepoPrefillProvider);
    final intentPrefill = ref.watch(launchIntentPrefillProvider);
    if (pre != null && pre.isNotEmpty && _appliedPrefill != pre) {
      _appliedPrefill = pre;
      _repoController.text = pre;
      Future.microtask(() {
        if (mounted) ref.read(launchRepoPrefillProvider.notifier).state = null;
      });
    }
    if (intentPrefill != null && _intent != intentPrefill) {
      _intent = intentPrefill;
      Future.microtask(() {
        if (mounted) ref.read(launchIntentPrefillProvider.notifier).state = null;
      });
    }

    final prefsAsync = ref.watch(preferencesProvider);
    final mordecaiUrl = prefsAsync.valueOrNull?.mordecaiCommissionsUrl.trim() ?? '';
    final showDesktopOption = mordecaiUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Launch Agent')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Repository URL', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _repoController,
              decoration: const InputDecoration(
                hintText: 'https://github.com/owner/repo',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Text('Branch / ref (optional)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _branchController,
              decoration: const InputDecoration(hintText: 'main'),
            ),
            const SizedBox(height: 16),
            Text('Prompt', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                hintText: 'Describe what you want the agent to do...',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            Text('Intent', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AgentIntent>(
              segments: const [
                ButtonSegment(
                  value: AgentIntent.normal,
                  label: Text('Launch'),
                  icon: Icon(Icons.rocket_launch_rounded),
                ),
                ButtonSegment(
                  value: AgentIntent.ask,
                  label: Text('Ask'),
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                ),
                ButtonSegment(
                  value: AgentIntent.plan,
                  label: Text('Plan'),
                  icon: Icon(Icons.route_rounded),
                ),
                ButtonSegment(
                  value: AgentIntent.debug,
                  label: Text('Debug'),
                  icon: Icon(Icons.bug_report_rounded),
                ),
              ],
              selected: {_intent},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                setState(() => _intent = selection.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _intent.shortDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('Gallery'),
                ),
                TextButton.icon(
                  onPressed: () => _pickImage(true),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Camera'),
                ),
                if (_imagePath != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _imagePath = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            if (_imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Image attached', style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 16),
            Text('Model', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _model,
              decoration: const InputDecoration(),
              items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _model = v ?? 'auto'),
            ),
            const SizedBox(height: 12),
            if (showDesktopOption) ...[
              SwitchListTile(
                title: const Text('Use desktop (saves tokens)'),
                subtitle: const Text(
                  'Send to your Cursor on desktop instead of Cloud API. Requires Mordecai + desktop extension.',
                ),
                value: _useDesktop,
                onChanged: (v) {
                  setState(() => _useDesktop = v);
                  ref.read(preferencesProvider.future).then((prefs) async {
                    await prefs.setPreferDesktopBridge(v);
                    ref.invalidate(preferencesProvider);
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
            if (_launchRouteNote != null) ...[
              const SizedBox(height: 8),
              Text(
                _launchRouteNote!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            SwitchListTile(
              title: const Text('Create pull request when done'),
              subtitle: const Text(
                'PR = pull request. Off by default; only enabled when this switch is on.',
              ),
              value: _autoCreatePr,
              onChanged: (v) => setState(() => _autoCreatePr = v),
            ),
            if (_launchError != null) ...[
              const SizedBox(height: 12),
              ErrorView(message: _launchError!, onRetry: _launch),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _launching ? null : _launch,
              icon: _launching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 20),
              label: Text(_launching ? 'Launching…' : 'Launch Agent'),
            ),
            if (_launchedAgentId != null && _launchedAgentId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Launched! Agent ID: $_launchedAgentId',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
