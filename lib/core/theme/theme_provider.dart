import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../constants/api_endpoints.dart';

const String _kThemePrefKey = 'app_theme_mode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_kThemePrefKey);
      if (savedMode == 'light') {
        state = ThemeMode.light;
      } else if (savedMode == 'dark') {
        state = ThemeMode.dark;
      } else if (savedMode == 'system') {
        state = ThemeMode.system;
      }
    } catch (e) {
      debugPrint('[ThemeNotifier] Error loading theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr = 'system';
      if (mode == ThemeMode.light) modeStr = 'light';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      await prefs.setString(_kThemePrefKey, modeStr);

      // Best-effort sync with backend profile
      try {
        await ApiClient().put(ApiEndpoints.me, data: {'themePreference': modeStr});
      } catch (_) {}
    } catch (e) {
      debugPrint('[ThemeNotifier] Error saving theme: $e');
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
