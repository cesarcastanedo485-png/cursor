import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent.dart';
import '../../core/constants.dart';

/// Offline cache for last agents list and timestamp.
class CacheService {
  CacheService(this._prefs);

  final SharedPreferences _prefs;

  static Future<CacheService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CacheService(prefs);
  }

  List<Agent> getCachedAgents() {
    final raw = _prefs.getString(cacheKeyAgents);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Agent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  DateTime? getCachedTimestamp() {
    final ts = _prefs.getInt(cacheKeyTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> saveAgents(List<Agent> agents) async {
    final list = agents.map((e) => e.toJson()).toList();
    await _prefs.setString(cacheKeyAgents, jsonEncode(list));
    await _prefs.setInt(cacheKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    await _prefs.remove(cacheKeyAgents);
    await _prefs.remove(cacheKeyTimestamp);
  }
}
