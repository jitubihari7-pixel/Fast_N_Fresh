import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// The app offers an explicit Light or Dark choice only. Installs that had
/// the old "System" setting are resolved once from the device brightness.
enum AppThemeMode { light, dark }

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';
  AppThemeMode _mode = AppThemeMode.dark;

  AppThemeMode get mode => _mode;
  bool get isDark => _mode == AppThemeMode.dark;
  bool isDarkForMode(AppThemeMode mode) => mode == AppThemeMode.dark;

  ThemeMode get themeMode =>
      _mode == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    _mode = switch (value) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      // First launch or the removed "System" option: follow the device once.
      _ => WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.light
          ? AppThemeMode.light
          : AppThemeMode.dark,
    };
    AppColors.setDarkMode(isDark);
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    // Keep legacy AppColors-based widgets synchronized with the selected
    // endpoint so the whole app switches at once.
    AppColors.setDarkMode(isDark);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  // Backward compatibility for older screens/callers.
  Future<void> setDarkMode(bool value) => setMode(value ? AppThemeMode.dark : AppThemeMode.light);
}
