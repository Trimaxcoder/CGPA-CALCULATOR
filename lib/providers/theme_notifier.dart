import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App theme: Light, Dark or System (follows the phone's setting).
/// `isDarkMode` is what the screens read — it already resolves "System".
class ThemeNotifier extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get themeMode => _mode;

  bool get isDarkMode =>
      _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  String get label {
    switch (_mode) {
      case ThemeMode.light:
        return 'Light theme';
      case ThemeMode.dark:
        return 'Dark theme';
      case ThemeMode.system:
        return 'System theme';
    }
  }

  ThemeNotifier() {
    WidgetsBinding.instance.addObserver(this);
    _loadFromPrefs();
  }

  // the phone switched between light and dark while we follow the system
  @override
  void didChangePlatformBrightness() {
    if (_mode == ThemeMode.system) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved != null) {
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.light,
      );
    } else {
      // older versions stored a simple dark/light flag
      _mode = (prefs.getBool('isDarkMode') ?? false)
          ? ThemeMode.dark
          : ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  // kept so older call sites keep working
  Future<void> toggleTheme() =>
      setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);

  Future<void> setDarkMode(bool value) =>
      setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
}