import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _LaunchAgentScreenState extends ConsumerState<LaunchAgentScreen> {
  final _repoController = TextEditingController();
  final _branchController = TextEditingController();
  final _promptController = TextEditingController();
  String _model = 'default';
  bool _autoCreatePr = false;
  String? _imagePath;
  bool _launching = false;
  String? _launchError;
  String? _launchedAgentId;
  String? _appliedPrefill;

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

  Future<void> _launch() async {
    final repo = _repoController.text.trim();
    final prompt = _promptController.text.trim();
    if (repo.isEmpty) {
      setState(() => _launchError = 'Enter a repository URL');
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
    });
    final branch = _branchController.text.trim();
    final imageB64 = await _imageToBase64();
    final request = LaunchRequest(
      repoUrl: repo,
      prompt: prompt,
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
      });
      if (agentId != null && agentId.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.agentDetail, arguments: agentId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _launching = false;
        _launchError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              value: _model,
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
