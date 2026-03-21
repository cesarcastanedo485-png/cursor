import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyDarkMode = 'cursor_mobile_dark_mode';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(skipInitialLoad: false);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier({bool skipInitialLoad = false}) : super(ThemeMode.dark) {
    if (!skipInitialLoad) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_keyDarkMode);
    state = isDark == false ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setDark(bool value) async {
    state = value ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  void toggle() => setDark(state != ThemeMode.dark);
}
