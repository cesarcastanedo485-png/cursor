import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capabilities_catalog.dart';
import '../data/local/secure_storage_service.dart';
import 'auth_provider.dart';

/// Config for one capability (by id).
final capabilityConfigProvider = FutureProvider.autoDispose.family<CapabilityConfig?, String>((ref, id) async {
  final storage = ref.watch(secureStorageProvider);
  return storage.getCapabilityConfig(id);
});

/// All configs for the catalog (for Configured badges).
final allCapabilityConfigsProvider = FutureProvider.autoDispose<Map<String, CapabilityConfig?>>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final map = <String, CapabilityConfig?>{};
  for (final c in kCapabilitiesCatalog) {
    map[c.id] = await storage.getCapabilityConfig(c.id);
  }
  return map;
});
