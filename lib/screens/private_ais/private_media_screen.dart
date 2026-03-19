import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/local/preferences_service.dart';
import '../../data/models/private_ai_preset.dart';
import '../../services/local_openai_service.dart';

/// Image / video generation attempt via OpenAI-compatible endpoints + copy-paste helpers.
class PrivateMediaScreen extends StatefulWidget {
  const PrivateMediaScreen({super.key, required this.preset, required this.config});

  final PrivateAiPreset preset;
  final PrivateAiStoredConfig config;

  @override
  State<PrivateMediaScreen> createState() => _PrivateMediaScreenState();
}

class _PrivateMediaScreenState extends State<PrivateMediaScreen> {
  final _prompt = TextEditingController();
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _tryGenerate() async {
    final p = _prompt.text.trim();
    if (p.isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final svc = LocalOpenAiService(
        baseUrl: widget.config.baseUrl,
        model: widget.config.model,
        apiKey: widget.config.apiKey.isEmpty ? null : widget.config.apiKey,
      );
      final url = await svc.imageGenerations(p);
      if (url != null && url.startsWith('http')) {
        setState(() => _result = 'Image URL: $url');
      } else if (url != null && url.length > 80) {
        setState(() => _result = 'Got base64 image (${url.length} chars). Paste into a base64 viewer or use ComfyUI.');
      } else {
        setState(() => _result =
            'No OpenAI /v1/images/generations response. ComfyUI usually needs a workflow API — see SETUP_PRIVATE_AIs.md. Try exposing a compatible gateway or use Save curl below.');
      }
    } catch (e) {
      setState(() => _result = 'Request failed: $e\n\nUse ComfyUI workflow + Tailscale per SETUP_PRIVATE_AIs.md.');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _copyCurl() {
    final body = jsonEncode({
      'model': widget.config.model,
      'prompt': _prompt.text.trim().isEmpty ? 'your prompt' : _prompt.text.trim(),
      'n': 1,
      'size': '512x512',
    });
    final curl =
        'curl -X POST "${widget.config.baseUrl}/v1/images/generations" -H "Content-Type: application/json" -d \'$body\'';
    Clipboard.setData(ClipboardData(text: curl));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('cURL copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.preset.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.preset.subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _prompt,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _tryGenerate,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_busy ? 'Trying…' : 'Try OpenAI-style image API'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copyCurl,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy sample cURL (any app)'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              SelectableText(_result!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 24),
            Text(
              'Video (LTX / WAN) is typically driven by ComfyUI workflows on your PC. '
              'Point base URL at a gateway that exposes OpenAI-compatible video, or run workflows locally — see SETUP_PRIVATE_AIs.md.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
