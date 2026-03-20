import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/preferences_service.dart';
import '../../data/models/private_ai_preset.dart';
import '../../providers/backend_mode_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../services/local_openai_service.dart';
import 'private_ai_chat_screen.dart';
import 'private_media_screen.dart';

/// List of private AI presets → chat (LLM) or media studio; configure from list or in-chat.
class PrivateAisScreen extends ConsumerStatefulWidget {
  const PrivateAisScreen({super.key});

  @override
  ConsumerState<PrivateAisScreen> createState() => _PrivateAisScreenState();
}

class _PrivateAisScreenState extends ConsumerState<PrivateAisScreen> {
  String? _testingId;

  Future<void> _openPreset(PrivateAiPreset p) async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text('Connecting…'),
            ],
          ),
        ),
      ),
    );
    try {
      final prefs = await ref.read(preferencesProvider.future);
      if (!mounted) {
        navigator.pop();
        return;
      }
      final cfg = prefs.getPrivateAiConfig(p.id) ?? p.defaultConfig(prefs);

      final svc = LocalOpenAiService(
        baseUrl: cfg.baseUrl,
        model: cfg.model,
        apiKey: cfg.apiKey.isEmpty ? null : cfg.apiKey,
      );
      final reachable = await svc.ping();
      if (!mounted) {
        navigator.pop();
        return;
      }
      navigator.pop(); // dismiss loading before next step
      if (!reachable) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Connection check'),
            content: Text(
              'Could not reach ${cfg.baseUrl}. '
              'Check Wi‑Fi, VPN, or that the server is running. Continue anyway?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue anyway')),
            ],
          ),
        );
        if (go != true || !mounted) return;
      }
      if (!mounted) return;
      if (p.kind == PrivateAiKind.llm) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => PrivateAiChatScreen(preset: p)),
        );
      } else {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => PrivateMediaScreen(preset: p, config: cfg)),
        );
      }
    } catch (e) {
      if (mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showQuickConfig(PrivateAiPreset p) async {
    final prefs = await ref.read(preferencesProvider.future);
    final c = prefs.getPrivateAiConfig(p.id) ?? p.defaultConfig(prefs);
    final url = TextEditingController(text: c.baseUrl);
    final model = TextEditingController(text: c.model);
    final key = TextEditingController(text: c.apiKey);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.title, style: Theme.of(ctx).textTheme.titleLarge),
              Text('Port hint: ${p.defaultPortHint}', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(controller: url, decoration: const InputDecoration(labelText: 'Base URL')),
              TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
              TextField(controller: key, obscureText: true, decoration: const InputDecoration(labelText: 'API key (optional)')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await prefs.setPrivateAiConfig(
                    p.id,
                    PrivateAiStoredConfig(
                      baseUrl: url.text.trim(),
                      model: model.text.trim(),
                      apiKey: key.text.trim(),
                    ),
                  );
                  ref.invalidate(activePrivateConfigProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  setState(() => _testingId = p.id);
                  try {
                    final svc = LocalOpenAiService(
                      baseUrl: url.text.trim(),
                      model: model.text.trim(),
                      apiKey: key.text.trim().isEmpty ? null : key.text.trim(),
                    );
                    final ok = await svc.ping();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Reachable' : 'Unreachable — check URL / VPN')),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  } finally {
                    if (mounted) setState(() => _testingId = null);
                  }
                },
                child: Text(_testingId == p.id ? 'Testing…' : 'Test connection'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () async {
                  await ref.read(backendStateProvider.notifier).usePrivateAiAsDefault(p.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Use as default private backend'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Private AIs'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: kPrivateAiPresets.length,
        itemBuilder: (context, i) {
          final p = kPrivateAiPresets[i];
          final isLlm = p.kind == PrivateAiKind.llm;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(p.title),
              subtitle: Text(p.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'URL / model / test',
                    onPressed: () => _showQuickConfig(p),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  FilledButton(
                    onPressed: () => _openPreset(p),
                    child: Text(isLlm ? 'Chat' : 'Studio'),
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
