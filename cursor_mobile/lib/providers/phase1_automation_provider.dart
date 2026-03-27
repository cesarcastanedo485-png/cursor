import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/phase1_automation_service.dart';
import 'auth_provider.dart';
import 'preferences_provider.dart';

final phase1AutomationServiceProvider =
    FutureProvider<Phase1AutomationService?>((ref) async {
  final prefs = await ref.watch(preferencesProvider.future);
  final baseUrl = prefs.mordecaiCommissionsUrl.trim();
  if (baseUrl.isEmpty) return null;
  final storage = ref.watch(secureStorageProvider);
  final bridgeSecret = await storage.getMordecaiBridgeSecret();
  return Phase1AutomationService(
    mordecaiBaseUrl: baseUrl,
    bridgeSecret: bridgeSecret,
  );
});
