import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ValueNotifier<ThemeMode> {
  ThemeService() : super(ThemeMode.dark);

  static const String _key = 'theme_mode';

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isLight = prefs.getBool(_key) ?? false; // Default to dark (false)
    value = isLight ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggleTheme() async {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value == ThemeMode.light);
  }
}

final themeService = ThemeService();
