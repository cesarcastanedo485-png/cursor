import 'package:mordechaius_maximus/data/local/secure_storage_service.dart';

/// In-memory mock for capability config lookup. Used for testing CapabilityService.
class MockCapabilityStorage implements CapabilityConfigProvider {
  final Map<String, CapabilityConfig> _configs = {};

  void setConfig(String capabilityId, CapabilityConfig config) {
    _configs[capabilityId] = config;
  }

  void clearConfig(String capabilityId) {
    _configs.remove(capabilityId);
  }

  @override
  Future<CapabilityConfig?> getCapabilityConfig(String capabilityId) async {
    return _configs[capabilityId];
  }
}
