import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModePreference {
  system, // следовать за системой
  light,
  dark;

  static ThemeModePreference fromName(String? name) => values.firstWhere(
    (m) => m.name == name,
    orElse: () => ThemeModePreference.system,
  );
}

class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'theme_mode_preference';

  ThemeModePreference _preference = ThemeModePreference.system;

  ThemeModePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
    ThemeModePreference.system => ThemeMode.system,
    ThemeModePreference.light => ThemeMode.light,
    ThemeModePreference.dark => ThemeMode.dark,
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = ThemeModePreference.fromName(prefs.getString(_prefsKey));
    if (saved != _preference) {
      _preference = saved;
      notifyListeners();
    }
  }

  Future<void> setPreference(ThemeModePreference mode) async {
    if (mode == _preference) return;
    _preference = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> toggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return setPreference(
      isDark ? ThemeModePreference.light : ThemeModePreference.dark,
    );
  }

  Future<void> animateToggle(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await setPreference(
      isDark ? ThemeModePreference.light : ThemeModePreference.dark,
    );
  }
}
