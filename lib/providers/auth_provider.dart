import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/secure_storage_service.dart';
import '../services/api_service.dart';
import '../services/capability_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) => SecureStorageService());

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Loads persisted API key once and hydrates [ApiService] before API calls.
final apiBootstrapProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final api = ref.watch(apiServiceProvider);
  final key = await storage.getApiKey();
  final normalized = key?.trim();
  if (normalized != null && normalized.isNotEmpty) {
    api.setApiKey(normalized);
  } else {
    api.clearApiKey();
  }
  return normalized;
});

final capabilityServiceProvider = Provider<CapabilityService>((ref) {
  return CapabilityService(ref.watch(secureStorageProvider));
});

/// Current API key (from secure storage). Null until loaded or set.
final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, AsyncValue<String?>>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiKeyNotifier(storage, ref.read(apiServiceProvider));
});

class ApiKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  ApiKeyNotifier(this._storage, this._api) : super(const AsyncValue.loading()) {
    load();
  }

  final SecureStorageService _storage;
  final ApiService _api;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final key = await _storage.getApiKey();
      state = AsyncValue.data(key);
      if (key != null && key.isNotEmpty) _api.setApiKey(key);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setKey(String key) async {
    await _storage.setApiKey(key);
    _api.setApiKey(key);
    state = AsyncValue.data(key);
  }

  Future<void> clearKey() async {
    await _storage.clearApiKey();
    _api.clearApiKey();
    state = const AsyncValue.data(null);
  }

  /// Test connection: GET /v0/agents. Returns null on success, error message on failure.
  Future<String?> testConnection() async {
    try {
      await _api.getAgents();
      return null;
    } catch (e) {
      final msg = e.toString();
      // Friendly message for network/DNS failures (e.g. no internet, blocked host)
      if (msg.contains('Failed host lookup') ||
          msg.contains('SocketException') ||
          msg.contains('No address associated with hostname') ||
          msg.contains('connection error') ||
          msg.contains('Connection refused')) {
        return "Can't reach Cursor's servers. Check your internet connection "
            "(Wi‑Fi or mobile data). If you're on Wi‑Fi, try mobile data or another network, then tap Test connection again.";
      }
      return msg.replaceFirst(RegExp(r'Exception:?\s*'), '');
    }
  }
}

/// True if user has completed onboarding (has valid key and passed test or saved).
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return storage.isOnboardingDone();
});

/// Convenience: is API configured (key present).
final isApiConfiguredProvider = Provider<bool>((ref) {
  final key = ref.watch(apiKeyProvider);
  return key.valueOrNull != null && key.valueOrNull!.isNotEmpty;
});

/// Whether user has completed onboarding (has key saved and proceeded).
final onboardingStateProvider = StateNotifierProvider<OnboardingStateNotifier, AsyncValue<bool>>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return OnboardingStateNotifier(storage);
});

class OnboardingStateNotifier extends StateNotifier<AsyncValue<bool>> {
  OnboardingStateNotifier(this._storage) : super(const AsyncValue.loading()) {
    _load();
  }
  final SecureStorageService _storage;

  Future<void> _load() async {
    try {
      final done = await _storage.isOnboardingDone();
      state = AsyncValue.data(done);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> complete() async {
    await _storage.setOnboardingDone(true);
    state = const AsyncValue.data(true);
  }

  Future<void> reset() async {
    await _storage.setOnboardingDone(false);
    state = const AsyncValue.data(false);
  }
}
