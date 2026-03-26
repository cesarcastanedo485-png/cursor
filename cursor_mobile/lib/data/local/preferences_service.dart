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
  static const _notifCreating = 'notif_agent_creating';
  static const _notifRunning = 'notif_agent_running';
  static const _notifFinished = 'notif_agent_finished';
  static const _notifExpired = 'notif_agent_expired';
  static const _notifAssistantMessage = 'notif_assistant_message';

  bool get connectGithubHintSeen => _prefs.getBool(_connectGithubSeen) ?? false;

  Future<void> setConnectGithubHintSeen(bool v) => _prefs.setBool(_connectGithubSeen, v);

  String get mordecaiCommissionsUrl => _prefs.getString(_mordecaiCommissionsUrl) ?? '';

  Future<void> setMordecaiCommissionsUrl(String v) => _prefs.setString(_mordecaiCommissionsUrl, v);

  bool get preferDesktopBridge => _prefs.getBool(_preferDesktopBridge) ?? true;

  Future<void> setPreferDesktopBridge(bool v) => _prefs.setBool(_preferDesktopBridge, v);

  String? get lastSeenVersion => _prefs.getString(_lastSeenVersion);

  Future<void> setLastSeenVersion(String v) => _prefs.setString(_lastSeenVersion, v);

  bool get notifAgentCreating => _prefs.getBool(_notifCreating) ?? true;
  bool get notifAgentRunning => _prefs.getBool(_notifRunning) ?? true;
  bool get notifAgentFinished => _prefs.getBool(_notifFinished) ?? true;
  bool get notifAgentExpired => _prefs.getBool(_notifExpired) ?? true;
  bool get notifAssistantMessage => _prefs.getBool(_notifAssistantMessage) ?? true;

  Future<void> setNotifAgentCreating(bool v) => _prefs.setBool(_notifCreating, v);
  Future<void> setNotifAgentRunning(bool v) => _prefs.setBool(_notifRunning, v);
  Future<void> setNotifAgentFinished(bool v) => _prefs.setBool(_notifFinished, v);
  Future<void> setNotifAgentExpired(bool v) => _prefs.setBool(_notifExpired, v);
  Future<void> setNotifAssistantMessage(bool v) => _prefs.setBool(_notifAssistantMessage, v);
}
