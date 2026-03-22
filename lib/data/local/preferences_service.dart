import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive app preferences (backend mode, private AI URLs, etc.).
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async {
    final p = await SharedPreferences.getInstance();
    return PreferencesService(p);
  }

  static const _backendMode = 'app_backend_mode';
  static const _activePrivateAi = 'active_private_ai_id';
  static const _localHost = 'local_server_host';
  static const _ollamaPort = 'local_ollama_port';
  static const _comfyPort = 'local_comfy_port';
  static const _connectGithubSeen = 'connect_github_hint_seen';
  static const _lastWhatsNewAckBuild = 'last_whats_new_ack_build';
  static const _mordecaiCommissionsUrl = 'mordecai_commissions_url';
  static const _privateConfigPrefix = 'private_ai_config_';

  String get backendMode => _prefs.getString(_backendMode) ?? 'cloud';

  Future<void> setBackendMode(String value) => _prefs.setString(_backendMode, value);

  String get activePrivateAiId => _prefs.getString(_activePrivateAi) ?? 'llm';

  Future<void> setActivePrivateAiId(String id) => _prefs.setString(_activePrivateAi, id);

  String get localServerHost => _prefs.getString(_localHost) ?? '192.168.1.100';

  Future<void> setLocalServerHost(String v) => _prefs.setString(_localHost, v);

  String get localOllamaPort => _prefs.getString(_ollamaPort) ?? '11434';

  Future<void> setLocalOllamaPort(String v) => _prefs.setString(_ollamaPort, v);

  String get localComfyPort => _prefs.getString(_comfyPort) ?? '8188';

  Future<void> setLocalComfyPort(String v) => _prefs.setString(_comfyPort, v);

  bool get connectGithubHintSeen => _prefs.getBool(_connectGithubSeen) ?? false;

  Future<void> setConnectGithubHintSeen(bool v) => _prefs.setBool(_connectGithubSeen, v);

  /// Last APK [buildNumber] for which the user dismissed the in-app "What's new" prompt.
  int get lastWhatsNewAcknowledgedBuild => _prefs.getInt(_lastWhatsNewAckBuild) ?? 0;

  Future<void> setLastWhatsNewAcknowledgedBuild(int build) =>
      _prefs.setInt(_lastWhatsNewAckBuild, build);

  String get mordecaiCommissionsUrl => _prefs.getString(_mordecaiCommissionsUrl) ?? '';

  Future<void> setMordecaiCommissionsUrl(String v) => _prefs.setString(_mordecaiCommissionsUrl, v);

  PrivateAiStoredConfig? getPrivateAiConfig(String aiId) {
    final raw = _prefs.getString('$_privateConfigPrefix$aiId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return PrivateAiStoredConfig.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  Future<void> setPrivateAiConfig(String aiId, PrivateAiStoredConfig config) async {
    await _prefs.setString('$_privateConfigPrefix$aiId', jsonEncode(config.toJson()));
  }
}

class PrivateAiStoredConfig {
  const PrivateAiStoredConfig({
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
  });

  final String baseUrl;
  final String model;
  final String apiKey;

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'model': model,
        'apiKey': apiKey,
      };

  static PrivateAiStoredConfig fromJson(Map<String, dynamic> j) => PrivateAiStoredConfig(
        baseUrl: j['baseUrl'] as String? ?? '',
        model: j['model'] as String? ?? '',
        apiKey: j['apiKey'] as String? ?? '',
      );

  PrivateAiStoredConfig copyWith({String? baseUrl, String? model, String? apiKey}) =>
      PrivateAiStoredConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
      );
}
