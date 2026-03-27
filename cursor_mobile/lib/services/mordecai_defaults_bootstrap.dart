import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mordecai_compile_defaults.dart';
import '../providers/auth_provider.dart';
import '../providers/bridge_task_provider.dart';
import '../providers/preferences_provider.dart';
import 'mordecai_health_service.dart';

/// Seeds Mordecai URL + bridge secret from `--dart-define` when storage is still empty.
Future<void> bootstrapMordecaiFromCompileDefaults(WidgetRef ref) async {
  final urlDef = MordecaiCompileDefaults.baseUrl.trim();
  final secretDef = MordecaiCompileDefaults.bridgeSecret.trim();
  if (urlDef.isEmpty && secretDef.isEmpty) return;

  final prefs = await ref.read(preferencesProvider.future);
  final storage = ref.read(secureStorageProvider);
  var didWrite = false;

  if (urlDef.isNotEmpty && prefs.mordecaiCommissionsUrl.trim().isEmpty) {
    final validation = MordecaiHealthService.validateForCommissions(
      urlDef,
      assumeMobileDevice: true,
    );
    if (validation.isValid && validation.normalizedUrl.isNotEmpty) {
      await prefs.setMordecaiCommissionsUrl(validation.normalizedUrl);
      didWrite = true;
    } else if (validation.error != null) {
      debugPrint('[Mordecai] Skipped MORDECAI_BASE_URL bootstrap: ${validation.error}');
    }
  }

  if (secretDef.isNotEmpty) {
    final existing = await storage.getMordecaiBridgeSecret();
    if (existing == null || existing.trim().isEmpty) {
      await storage.setMordecaiBridgeSecret(secretDef);
      didWrite = true;
    }
  }

  if (didWrite) {
    ref.invalidate(preferencesProvider);
    ref.invalidate(bridgeTaskServiceProvider);
  }
}
