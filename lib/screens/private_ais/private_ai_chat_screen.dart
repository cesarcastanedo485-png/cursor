import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../data/local/preferences_service.dart';
import '../../data/models/private_ai_preset.dart';
import '../../providers/backend_mode_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../data/local/private_chat_repository.dart';
import '../../providers/private_chat_provider.dart';
import '../../services/local_openai_service.dart';

/// Per-AI persistent chat with TTS, image/video attach, cross-AI memory.
class PrivateAiChatScreen extends ConsumerStatefulWidget {
  const PrivateAiChatScreen({super.key, required this.preset});

  final PrivateAiPreset preset;

  @override
  ConsumerState<PrivateAiChatScreen> createState() => _PrivateAiChatScreenState();
}

class _PrivateAiChatScreenState extends ConsumerState<PrivateAiChatScreen> {
  final _input = TextEditingController();
  final _tts = FlutterTts();
  bool _sending = false;
  String? _pendingImageB64;
  String? _pendingImageMime;
  String? _pendingVideoPath;
  VideoPlayerController? _videoCtrl;
  List<PrivateChatEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadThread());
  }

  void _reloadThread() {
    final repo = ref.read(privateChatRepositoryProvider);
    setState(() => _entries = repo.threadForAi(widget.preset.id));
  }

  @override
  void dispose() {
    _input.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<PrivateAiStoredConfig> _cfg() async {
    final prefs = await ref.read(preferencesProvider.future);
    final p = widget.preset;
    final stored = prefs.getPrivateAiConfig(p.id);
    final def = p.defaultConfig(prefs);
    if (stored == null) return def;
    return PrivateAiStoredConfig(
      baseUrl: stored.baseUrl.isNotEmpty ? stored.baseUrl : def.baseUrl,
      model: stored.model.isNotEmpty ? stored.model : def.model,
      apiKey: stored.apiKey,
    );
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _pendingImageB64 = base64Encode(bytes);
      _pendingImageMime = 'image/jpeg';
      _pendingVideoPath = null;
      _videoCtrl?.dispose();
      _videoCtrl = null;
    });
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    _videoCtrl?.dispose();
    final c = VideoPlayerController.file(File(x.path));
    await c.initialize();
    setState(() {
      _pendingVideoPath = x.path;
      _pendingImageB64 = null;
      _pendingImageMime = null;
      _videoCtrl = c;
    });
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text.length > 4000 ? text.substring(0, 4000) : text);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _pendingImageB64 == null && _pendingVideoPath == null) || _sending) return;

    final repo = ref.read(privateChatRepositoryProvider);
    final aiId = widget.preset.id;
    var userVisible = text;
    if (_pendingVideoPath != null) {
      userVisible = userVisible.isEmpty
          ? '[Video attached — describe or process per your capabilities.]'
          : '$userVisible\n[Video file attached for context.]';
    }
    if (_pendingImageB64 != null) {
      userVisible = userVisible.isEmpty ? '[Image attached]' : '$userVisible\n[Image attached]';
    }

    final imgB64 = _pendingImageB64;
    final imgMime = _pendingImageMime;

    await repo.append(aiId: aiId, role: 'user', content: userVisible, mediaNote: _pendingVideoPath ?? (imgB64 != null ? 'image' : null));
    setState(() {
      _sending = true;
      _input.clear();
      _pendingImageB64 = null;
      _pendingImageMime = null;
      _pendingVideoPath = null;
      _videoCtrl?.dispose();
      _videoCtrl = null;
    });

    final cfg = await _cfg();
    final svc = LocalOpenAiService(
      baseUrl: cfg.baseUrl,
      model: cfg.model,
      apiKey: cfg.apiKey.isEmpty ? null : cfg.apiKey,
    );

    final global = repo.globalMemoryExcerpt(aiId);
    final thread = repo.threadForAi(aiId);

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'You are "${widget.preset.title}" in Mordechaius Maximus. Prior context from other private AIs (may be empty):\n$global',
      },
    ];

    for (var i = 0; i < thread.length; i++) {
      final e = thread[i];
      final isLastUser = i == thread.length - 1 && e.role == 'user';
      if (isLastUser && imgB64 != null && imgMime != null) {
        messages.add({
          'role': 'user',
          'content': [
            if (text.isNotEmpty) {'type': 'text', 'text': text},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$imgMime;base64,$imgB64'},
            },
          ],
        });
      } else {
        messages.add({'role': e.role, 'content': e.content});
      }
    }

    try {
      final reply = await svc.chatCompletion(messages);
      await repo.append(aiId: aiId, role: 'assistant', content: reply);
    } catch (e) {
      await repo.append(aiId: aiId, role: 'assistant', content: 'Error: $e');
    }
    if (mounted) {
      setState(() => _sending = false);
      _reloadThread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiId = widget.preset.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.preset.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showConfig(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear this thread?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(privateChatRepositoryProvider).clearThread(aiId);
                _reloadThread();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(
                      'Say hello. Chats are saved locally. Other AIs\' history is summarized in context.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final user = e.role == 'user';
                      return Align(
                        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.9),
                          decoration: BoxDecoration(
                            color: user
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(e.content, style: Theme.of(context).textTheme.bodyMedium),
                              if (!user)
                                TextButton.icon(
                                  onPressed: () => _speak(e.content),
                                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                                  label: const Text('Speak'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_pendingImageB64 != null)
            SizedBox(height: 80, child: Image.memory(base64Decode(_pendingImageB64!), fit: BoxFit.contain)),
          if (_videoCtrl != null && _videoCtrl!.value.isInitialized)
            SizedBox(
              height: 120,
              child: AspectRatio(
                aspectRatio: _videoCtrl!.value.aspectRatio,
                child: VideoPlayer(_videoCtrl!),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: _sending ? null : _pickImage, icon: const Icon(Icons.image_rounded)),
                      IconButton(onPressed: _sending ? null : _pickVideo, icon: const Icon(Icons.videocam_rounded)),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Message…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfig(BuildContext ctx) async {
    final prefs = await ref.read(preferencesProvider.future);
    final p = widget.preset;
    final c = prefs.getPrivateAiConfig(p.id) ?? p.defaultConfig(prefs);
    final url = TextEditingController(text: c.baseUrl);
    final model = TextEditingController(text: c.model);
    final key = TextEditingController(text: c.apiKey);
    if (!ctx.mounted) return;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx2) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(ctx2).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Configure ${p.title}', style: Theme.of(ctx2).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'Base URL')),
            TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
            TextField(controller: key, obscureText: true, decoration: const InputDecoration(labelText: 'API key (optional)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await prefs.setPrivateAiConfig(
                  p.id,
                  PrivateAiStoredConfig(baseUrl: url.text.trim(), model: model.text.trim(), apiKey: key.text.trim()),
                );
                ref.invalidate(activePrivateConfigProvider);
                if (ctx2.mounted) Navigator.pop(ctx2);
              },
              child: const Text('Save'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () async {
                await ref.read(backendStateProvider.notifier).usePrivateAiAsDefault(p.id);
                if (ctx2.mounted) Navigator.pop(ctx2);
              },
              child: const Text('Use as default private backend'),
            ),
          ],
        ),
      ),
    );
  }
}
