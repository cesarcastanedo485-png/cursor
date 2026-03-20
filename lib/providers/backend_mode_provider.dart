import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/preferences_service.dart';
import '../data/models/private_ai_preset.dart';
import 'preferences_provider.dart';

enum AppBackendMode {
  cursorCloud,
  privateLocal,
}

class BackendState {
  const BackendState({
    required this.mode,
    required this.activePrivateAiId,
  });

  final AppBackendMode mode;
  final String activePrivateAiId;

  String get bannerSubtitle {
    if (mode == AppBackendMode.cursorCloud) return 'Cloud Agents';
    final p = presetById(activePrivateAiId);
    return p != null ? 'Private · ${p.title}' : 'Private AI';
  }
}

final backendStateProvider = StateNotifierProvider<BackendStateNotifier, BackendState>((ref) {
  return BackendStateNotifier(ref);
});

class BackendStateNotifier extends StateNotifier<BackendState> {
  BackendStateNotifier(this._ref)
      : super(const BackendState(mode: AppBackendMode.cursorCloud, activePrivateAiId: 'llm')) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final prefs = await _ref.read(preferencesProvider.future);
      state = BackendState(
        mode: prefs.backendMode == 'private' ? AppBackendMode.privateLocal : AppBackendMode.cursorCloud,
        activePrivateAiId: prefs.activePrivateAiId,
      );
    } catch (_) {
      // Keep default state if prefs fail (e.g. first run)
    }
  }

  Future<void> setMode(AppBackendMode mode) async {
    final prefs = await _ref.read(preferencesProvider.future);
    await prefs.setBackendMode(mode == AppBackendMode.cursorCloud ? 'cloud' : 'private');
    state = BackendState(mode: mode, activePrivateAiId: state.activePrivateAiId);
  }

  Future<void> usePrivateAiAsDefault(String aiId) async {
    final prefs = await _ref.read(preferencesProvider.future);
    await prefs.setActivePrivateAiId(aiId);
    await prefs.setBackendMode('private');
    state = BackendState(mode: AppBackendMode.privateLocal, activePrivateAiId: aiId);
  }

  Future<void> switchToCloud() async {
    await setMode(AppBackendMode.cursorCloud);
  }

  Future<void> refreshFromPrefs() => _load();
}

final activePrivatePresetProvider = Provider<PrivateAiPreset?>((ref) {
  final id = ref.watch(backendStateProvider).activePrivateAiId;
  return presetById(id);
});

final activePrivateConfigProvider = FutureProvider<PrivateAiStoredConfig>((ref) async {
  final prefs = await ref.watch(preferencesProvider.future);
  final st = ref.watch(backendStateProvider);
  final id = st.activePrivateAiId;
  final preset = presetById(id);
  final stored = prefs.getPrivateAiConfig(id);
  if (preset == null) {
    return stored ?? const PrivateAiStoredConfig(baseUrl: 'http://127.0.0.1:11434', model: 'qwen3.5:72b');
  }
  final def = preset.defaultConfig(prefs);
  if (stored == null) return def;
  return PrivateAiStoredConfig(
    baseUrl: stored.baseUrl.isNotEmpty ? stored.baseUrl : def.baseUrl,
    model: stored.model.isNotEmpty ? stored.model : def.model,
    apiKey: stored.apiKey,
  );
});

/// Legacy alias for widgets checking cloud vs private.
final appBackendModeProvider = Provider<AppBackendMode>((ref) => ref.watch(backendStateProvider).mode);
