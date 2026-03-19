import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_errors.dart';
import '../data/local/secure_storage_service.dart';
import '../data/models/cursor_repository.dart';
import '../services/repos_anti_loop.dart';
import 'auth_provider.dart';

/// Banner / helper text when anti-loop skips the Cursor API (circuit, cooldown).
final reposAntiLoopMessageProvider = StateProvider<String?>((ref) => null);

/// Cursor Cloud repositories + anti-loop (no hammering /v0/repositories).
final repositoriesProvider =
    AsyncNotifierProvider<CursorReposNotifier, List<CursorRepository>>(CursorReposNotifier.new);

class CursorReposNotifier extends AsyncNotifier<List<CursorRepository>> {
  @override
  Future<List<CursorRepository>> build() async {
    return _load(force: false);
  }

  /// Normal refresh: respects circuit breaker and min interval.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(force: false));
  }

  /// Clears circuit once and hits the API (for power users / after Cursor fixes backend).
  Future<void> forceApiRetry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(force: true));
  }

  Future<List<CursorRepository>> _load({required bool force}) async {
    final key = ref.read(apiKeyProvider).valueOrNull?.trim();
    if (key == null || key.isEmpty) {
      ref.read(reposAntiLoopMessageProvider.notifier).state = null;
      throw Exception('Add your Cursor API key in Settings to load repositories.');
    }

    final gate = await ReposAntiLoop.checkGate(force: force);
    if (!gate.allowFetch) {
      ref.read(reposAntiLoopMessageProvider.notifier).state = gate.userMessage;
      return [];
    }
    ref.read(reposAntiLoopMessageProvider.notifier).state = null;

    await ReposAntiLoop.markAttemptStart();
    final api = ref.read(apiServiceProvider);
    api.setApiKey(key);
    try {
      final list = await api.getRepositories();
      await ReposAntiLoop.onSuccess();
      return list;
    } catch (e) {
      if (isUnauthorizedError(e)) {
        await ReposAntiLoop.on401Unauthorized();
        final suppress = await ReposAntiLoop.shouldSuppressErrorUi();
        if (suppress) {
          ref.read(reposAntiLoopMessageProvider.notifier).state =
              'Cursor repo API keeps returning unauthorized. Automatic retries are paused—use manual repos or “Force API retry”.';
          return [];
        }
      }
      rethrow;
    }
  }
}

/// Manual repo list (workaround when GET /v0/repositories returns 401).
final manualReposProvider = StateNotifierProvider<ManualReposNotifier, List<CursorRepository>>((ref) {
  return ManualReposNotifier(ref.read(secureStorageProvider));
});

class ManualReposNotifier extends StateNotifier<List<CursorRepository>> {
  ManualReposNotifier(this._storage) : super([]) {
    _load();
  }
  final SecureStorageService _storage;

  Future<void> _load() async {
    final urls = await _storage.getManualRepoUrls();
    state = urls
        .map((u) => CursorRepository.fromUrl(u))
        .whereType<CursorRepository>()
        .toList();
  }

  Future<void> addUrl(String url) async {
    final repo = CursorRepository.fromUrl(url);
    if (repo == null) return;
    final urls = await _storage.getManualRepoUrls();
    final normalized = repo.htmlUrl ?? repo.repoUrl;
    if (urls.any((u) => _norm(u) == _norm(normalized))) return;
    urls.add(normalized);
    await _storage.setManualRepoUrls(urls);
    state = urls
        .map((u) => CursorRepository.fromUrl(u))
        .whereType<CursorRepository>()
        .toList();
  }

  Future<void> removeUrl(String url) async {
    final urls = await _storage.getManualRepoUrls();
    urls.removeWhere((u) => _norm(u) == _norm(url));
    await _storage.setManualRepoUrls(urls);
    state = urls
        .map((u) => CursorRepository.fromUrl(u))
        .whereType<CursorRepository>()
        .toList();
  }

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceFirst(RegExp(r'\.git$'), '');
}
