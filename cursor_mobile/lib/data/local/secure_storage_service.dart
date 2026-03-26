import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal interface for capability config lookup. Allows testing with mocks.
abstract class CapabilityConfigProvider {
  Future<CapabilityConfig?> getCapabilityConfig(String capabilityId);
}

/// Keys for secure storage.
const String _keyApiKey = 'cursor_cloud_agents_api_key';
const String _keyOnboardingDone = 'onboarding_done';
const String _keyCapabilityPrefix = 'capability_config_';
const String _keyManualRepoUrls = 'manual_repo_urls';
const String _keyFcmToken = 'fcm_token';
const String _keyMordecaiBridgeSecret = 'mordecai_bridge_secret';

/// Encrypted storage for API key, onboarding state, and capability config.
class SecureStorageService implements CapabilityConfigProvider {
  SecureStorageService() : _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  Future<String?> getApiKey() => _storage.read(key: _keyApiKey);

  Future<void> setApiKey(String value) => _storage.write(key: _keyApiKey, value: value);

  Future<void> clearApiKey() => _storage.delete(key: _keyApiKey);

  Future<bool> isOnboardingDone() async {
    final v = await _storage.read(key: _keyOnboardingDone);
    return v == 'true';
  }

  Future<void> setOnboardingDone(bool value) =>
      _storage.write(key: _keyOnboardingDone, value: value.toString());

  /// Capability config (API key, webhook URL, folder path) per capability id.
  @override
  Future<CapabilityConfig?> getCapabilityConfig(String capabilityId) async {
    final raw = await _storage.read(key: '$_keyCapabilityPrefix$capabilityId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CapabilityConfig.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  Future<void> setCapabilityConfig(String capabilityId, CapabilityConfig config) async {
    await _storage.write(
      key: '$_keyCapabilityPrefix$capabilityId',
      value: jsonEncode(config.toJson()),
    );
  }

  Future<void> clearCapabilityConfig(String capabilityId) async {
    await _storage.delete(key: '$_keyCapabilityPrefix$capabilityId');
  }

  /// Manual repo URLs when Cursor API /v0/repositories returns 401 (workaround).
  Future<List<String>> getManualRepoUrls() async {
    final raw = await _storage.read(key: _keyManualRepoUrls);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setManualRepoUrls(List<String> urls) async {
    await _storage.write(key: _keyManualRepoUrls, value: jsonEncode(urls));
  }

  /// FCM token for push notifications.
  Future<String?> getFcmToken() => _storage.read(key: _keyFcmToken);

  Future<void> setFcmToken(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _keyFcmToken);
    } else {
      await _storage.write(key: _keyFcmToken, value: value);
    }
  }

  /// Mordecai bridge secret for task queue API (X-Bridge-Secret header).
  Future<String?> getMordecaiBridgeSecret() => _storage.read(key: _keyMordecaiBridgeSecret);

  Future<void> setMordecaiBridgeSecret(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _storage.delete(key: _keyMordecaiBridgeSecret);
    } else {
      await _storage.write(key: _keyMordecaiBridgeSecret, value: value.trim());
    }
  }
}

/// Stored config for a capability (Tools tab).
class CapabilityConfig {
  const CapabilityConfig({
    this.apiKey = '',
    this.webhookUrl = '',
    this.folderPath = '',
  });

  final String apiKey;
  final String webhookUrl;
  final String folderPath;

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'webhookUrl': webhookUrl,
        'folderPath': folderPath,
      };

  static CapabilityConfig fromJson(Map<String, dynamic> j) => CapabilityConfig(
        apiKey: j['apiKey'] as String? ?? '',
        webhookUrl: j['webhookUrl'] as String? ?? '',
        folderPath: j['folderPath'] as String? ?? '',
      );

  bool get isConfigured =>
      apiKey.trim().isNotEmpty ||
      webhookUrl.trim().isNotEmpty ||
      folderPath.trim().isNotEmpty;
}
