import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants.dart';
import '../../../data/models/launch_request.dart';
import '../../../providers/agents_provider.dart';
import '../../../providers/backend_mode_provider.dart';
import '../../../providers/shell_providers.dart';
import '../../widgets/error_view.dart';

/// Launch agent: repo URL, prompt, options, POST /v0/agents.
class LaunchAgentScreen extends ConsumerStatefulWidget {
  const LaunchAgentScreen({super.key});

  @override
  ConsumerState<LaunchAgentScreen> createState() => _LaunchAgentScreenState();
}

enum _LaunchIntent { ask, plan, debug }

class _LaunchAgentScreenState extends ConsumerState<LaunchAgentScreen> {
  final _repoController = TextEditingController();
  final _branchController = TextEditingController();
  final _promptController = TextEditingController();
  String _model = 'default';
  _LaunchIntent _intent = _LaunchIntent.ask;
  bool _autoCreatePr = false;
  String? _imagePath;
  bool _launching = false;
  String? _launchError;
  String? _launchedAgentId;
  String? _appliedPrefill;

  void _clearLaunchDraft() {
    _promptController.clear();
    setState(() {
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

  static const _models = ['default', 'claude-4-sonnet', 'claude-4-opus', 'gpt-4o'];

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
    setState(() {
      _launching = true;
      _launchError = null;
      _launchedAgentId = null;
      _repoController.text = repo;
    });
    final branch = _branchController.text.trim();
    final imageB64 = await _imageToBase64();
    final effectivePrompt = _buildPromptForIntent(prompt);
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

  String _buildPromptForIntent(String userPrompt) {
    switch (_intent) {
      case _LaunchIntent.ask:
        return userPrompt;
      case _LaunchIntent.plan:
        return [
          'Intent: Plan',
          'First provide a concise implementation plan, then execute the work in ordered steps.',
          userPrompt,
        ].join('\n\n');
      case _LaunchIntent.debug:
        return [
          'Intent: Debug',
          'Treat this as a debugging task: reproduce the issue, identify root cause, explain findings, and apply the smallest safe fix with verification.',
          userPrompt,
        ].join('\n\n');
    }
  }

  String _intentHelpText() {
    switch (_intent) {
      case _LaunchIntent.ask:
        return 'General request. Best for normal coding or Q&A tasks.';
      case _LaunchIntent.plan:
        return 'Agent starts with an explicit plan before implementation.';
      case _LaunchIntent.debug:
        return 'Agent prioritizes root-cause analysis, minimal fix, and verification.';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(launchTabResetCounterProvider, (previous, next) {
      if (previous != null && next > previous && mounted) {
        _clearLaunchDraft();
      }
    });

    final private = ref.watch(appBackendModeProvider) == AppBackendMode.privateLocal;
    final pre = ref.watch(launchRepoPrefillProvider);
    if (!private && pre != null && pre.isNotEmpty && _appliedPrefill != pre) {
      _appliedPrefill = pre;
      _repoController.text = pre;
      Future.microtask(() {
        if (mounted) ref.read(launchRepoPrefillProvider.notifier).state = null;
      });
    }

    if (private) {
      return Scaffold(
        appBar: AppBar(title: const Text('Launch Agent')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'Cursor Cloud agents run on Cursor’s cloud. Switch to Cursor Cloud to launch an agent from a repo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => ref.read(backendStateProvider.notifier).switchToCloud(),
                  child: const Text('Switch to Cursor Cloud'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
            SegmentedButton<_LaunchIntent>(
              segments: const [
                ButtonSegment(
                  value: _LaunchIntent.ask,
                  label: Text('Ask'),
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                ),
                ButtonSegment(
                  value: _LaunchIntent.plan,
                  label: Text('Plan'),
                  icon: Icon(Icons.route_rounded),
                ),
                ButtonSegment(
                  value: _LaunchIntent.debug,
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
              _intentHelpText(),
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
              onChanged: (v) => setState(() => _model = v ?? 'default'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Create pull request when done'),
              subtitle: const Text(
                'PR = pull request: open a proposed change on GitHub for review before merging.',
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
