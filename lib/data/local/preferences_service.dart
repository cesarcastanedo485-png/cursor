import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive app preferences.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async {
    final p = await SharedPreferences.getInstance();
    return PreferencesService(p);
  }

  static const _connectGithubSeen = 'connect_github_hint_seen';
  static const _mordecaiCommissionsUrl = 'mordecai_commissions_url';
  static const _preferDesktopBridge = 'prefer_desktop_bridge';
  static const _lastSeenVersion = 'last_seen_version';

  bool get connectGithubHintSeen => _prefs.getBool(_connectGithubSeen) ?? false;

  Future<void> setConnectGithubHintSeen(bool v) => _prefs.setBool(_connectGithubSeen, v);

  String get mordecaiCommissionsUrl => _prefs.getString(_mordecaiCommissionsUrl) ?? '';

  Future<void> setMordecaiCommissionsUrl(String v) => _prefs.setString(_mordecaiCommissionsUrl, v);

  bool get preferDesktopBridge => _prefs.getBool(_preferDesktopBridge) ?? true;

  Future<void> setPreferDesktopBridge(bool v) => _prefs.setBool(_preferDesktopBridge, v);

  String? get lastSeenVersion => _prefs.getString(_lastSeenVersion);

  Future<void> setLastSeenVersion(String v) => _prefs.setString(_lastSeenVersion, v);
}
