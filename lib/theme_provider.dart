import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = Colors.green; // Varsayılan tema rengi
  bool _isDarkMode = false; // Varsayılan tema

  Color get primaryColor =>
    _isDarkMode ? getDarkShade(_primaryColor) : _primaryColor;
  
  // Orijinal rengi dışarıya veriyoruz (karanlık modda koyulaşmamış hali)
  Color get rawPrimaryColor => _primaryColor;

  bool get isDarkMode => _isDarkMode;

  Color getDarkShade(Color color) {
  // Rengi %30 koyulaştırıyoruz
  const double factor = 0.30;

  final r = (color.red * (1 - factor)).round();
  final g = (color.green * (1 - factor)).round();
  final b = (color.blue * (1 - factor)).round();

  return Color.fromRGBO(r, g, b, 1);
}

  ThemeProvider() {
    _loadTheme(); // Uygulama açılırken tema ayarını yükle
  }

  // ------------------------------------------------------
  // 📌 Kayıtlı tema ayarlarını cihazdan yükle
  // ------------------------------------------------------
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final colorValue = prefs.getInt("themeColor");
    final darkModePref = prefs.getBool("isDarkMode");

    if (colorValue != null) {
      _primaryColor = Color(colorValue);
    }

    if (darkModePref != null) {
      _isDarkMode = darkModePref;
    }

    notifyListeners();
  }

  void setPrimaryColor(Color color) {
  _primaryColor = color;
  notifyListeners(); // Bu satır kesin olmalı
}

  Color get effectivePrimaryColor {
    if (_isDarkMode) {
      // Koyu mod -> açık renk (örneğin pastel ton)
      return getLightShade(_primaryColor);
    } else {
      // Açık mod -> koyu renk
      return getDarkShade(_primaryColor);
    }
  }


  Color getLightShade(Color color) {
    const factor = 0.4;
    return Color.fromRGBO(
      (color.red + (255 - color.red) * factor).round(),
      (color.green + (255 - color.green) * factor).round(),
      (color.blue + (255 - color.blue) * factor).round(),
      1,
    );
  }

  

  // ------------------------------------------------------
  // 🎨 TEMAYI (RENK) DEĞİŞTİR
  // ------------------------------------------------------
  Future<void> setTheme(Color newColor) async {
    _primaryColor = newColor;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("themeColor", newColor.value);
  }

  // ------------------------------------------------------
  // 🌙 KARANLIK MODU AÇ / KAPAT
  // ------------------------------------------------------
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isDarkMode", value);
  }

  // ------------------------------------------------------
  // 🌞 AÇIK TEMA (MODERN + MATERIAL 3)
  // ------------------------------------------------------
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),

      primaryColor: _primaryColor,

      // ⭐ TÜM YAZILAR SİYAH
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
        bodySmall: TextStyle(color: Colors.black),
        titleLarge: TextStyle(color: Colors.black),
        titleMedium: TextStyle(color: Colors.black),
        titleSmall: TextStyle(color: Colors.black),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
      ),
    );
  }

  // ------------------------------------------------------
  // 🌙 KARANLIK TEMA (MODERN + MATERIAL 3)
  // ------------------------------------------------------
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),

      primaryColor: getDarkShade(_primaryColor),

      // ⭐ TÜM YAZILAR BEYAZ
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
      ),
    );
  }
}
