import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'preferences_provider.dart';
import '../services/bridge_task_service.dart';
import '../services/mordecai_health_service.dart';

/// Bridge task service when Mordecai URL is configured. Null otherwise.
final bridgeTaskServiceProvider = FutureProvider<BridgeTaskService?>((ref) async {
  final prefs = await ref.watch(preferencesProvider.future);
  final storage = ref.watch(secureStorageProvider);
  final url = MordecaiHealthService.normalizeBaseUrl(
    prefs.mordecaiCommissionsUrl.trim(),
  );
  if (url.isEmpty) return null;
  final secret = await storage.getMordecaiBridgeSecret();
  return BridgeTaskService(
    mordecaiBaseUrl: url,
    bridgeSecret: secret,
  );
});

/// FCM token for push on task completion. Null if not available.
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return storage.getFcmToken();
});
