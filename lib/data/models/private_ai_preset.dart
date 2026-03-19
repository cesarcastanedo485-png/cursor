import '../local/preferences_service.dart';

/// One of five pre-configured private AI slots (OpenAI-compatible base URL + model).
class PrivateAiPreset {
  const PrivateAiPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.defaultModel,
    required this.defaultPortHint,
    required this.kind,
  });

  final String id;
  final String title;
  final String subtitle;
  final String defaultModel;
  final String defaultPortHint;
  final PrivateAiKind kind;

  String defaultBaseUrl(PreferencesService prefs) {
    final host = prefs.localServerHost;
    switch (kind) {
      case PrivateAiKind.llm:
      case PrivateAiKind.sfwImage:
        return 'http://$host:${prefs.localOllamaPort}';
      case PrivateAiKind.sfwVideo:
      case PrivateAiKind.nsfwImage:
      case PrivateAiKind.nsfwVideo:
        return 'http://$host:${prefs.localComfyPort}';
    }
  }

  PrivateAiStoredConfig defaultConfig(PreferencesService prefs) => PrivateAiStoredConfig(
        baseUrl: defaultBaseUrl(prefs),
        model: defaultModel,
        apiKey: '',
      );
}

enum PrivateAiKind { llm, sfwImage, sfwVideo, nsfwImage, nsfwVideo }

const List<PrivateAiPreset> kPrivateAiPresets = [
  PrivateAiPreset(
    id: 'llm',
    title: 'Qwen3.5 LLM',
    subtitle: 'Qwen3.5 72B via Ollama — OpenAI-compatible chat; supports vision if your model does.',
    defaultModel: 'qwen3.5:72b',
    defaultPortHint: '11434',
    kind: PrivateAiKind.llm,
  ),
  PrivateAiPreset(
    id: 'sfw_image',
    title: 'SFW Image Gen',
    subtitle: 'Best free: FLUX.2 Klein via Ollama or ComfyUI workflow (OpenAI-style where supported).',
    defaultModel: 'flux2-klein',
    defaultPortHint: '11434 / 8188',
    kind: PrivateAiKind.sfwImage,
  ),
  PrivateAiPreset(
    id: 'sfw_video',
    title: 'SFW Video Gen',
    subtitle: 'Best free: LTX-2.3 via ComfyUI API or compatible proxy.',
    defaultModel: 'ltx-2.3',
    defaultPortHint: '8188',
    kind: PrivateAiKind.sfwVideo,
  ),
  PrivateAiPreset(
    id: 'nsfw_image',
    title: 'NSFW Image Gen',
    subtitle: 'Uncensored: Pony Diffusion V6 + Flux merge via ComfyUI (local only).',
    defaultModel: 'pony-v6-flux',
    defaultPortHint: '8188',
    kind: PrivateAiKind.nsfwImage,
  ),
  PrivateAiPreset(
    id: 'nsfw_video',
    title: 'NSFW Video Gen',
    subtitle: 'Uncensored: LTX-2.3 uncensored or WAN 2.2 Remix via ComfyUI.',
    defaultModel: 'wan-2.2-remix',
    defaultPortHint: '8188',
    kind: PrivateAiKind.nsfwVideo,
  ),
];

PrivateAiPreset? presetById(String id) {
  for (final p in kPrivateAiPresets) {
    if (p.id == id) return p;
  }
  return null;
}
