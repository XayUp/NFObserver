import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importar SharedPreferences

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeNotifier(this._themeMode);

  ThemeMode get themeMode => _themeMode;

  static Future<int> getThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('themeMode') ?? ThemeMode.system.index;
  }

  Future<void> loadTheme() async {
    final themeModeIndex = await getThemeIndex();
    _themeMode = ThemeMode.values[themeModeIndex];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode newThemeMode) async {
    if (_themeMode != newThemeMode) {
      _themeMode = newThemeMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'themeMode',
        newThemeMode.index,
      ); // Agora podemos usar await
      notifyListeners();
    }
  }
}
