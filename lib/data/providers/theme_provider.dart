import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey =  'theme_mode';
  AppThemeMode _themeMode = AppThemeMode.system;
  SharedPreferences? _prefs;

  AppThemeMode get themeMode => _themeMode;

  ThemeMode get effectiveThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString(_themeKey);
    
    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeMode = AppThemeMode.light;
          break;
        case 'dark':
          _themeMode = AppThemeMode.dark;
          break;
        case 'system':
          _themeMode = AppThemeMode.system;
          break;
      }
    }
    
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    
    String modeString;
    switch (mode) {
      case AppThemeMode.light:
        modeString = 'light';
        break;
      case AppThemeMode.dark:
        modeString = 'dark';
        break;
      case AppThemeMode.system:
        modeString = 'system';
        break;
    }
    
    await _prefs?.setString(_themeKey, modeString);
    notifyListeners();
  }
}
