// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _fontFamilyKey = 'fontFamily';
  static const String _fontSizeKey = 'fontSize';
  static const String _lineHeightKey = 'lineHeight';

  String _fontFamily = 'Inter';
  double _fontSize = 18;
  double _lineHeight = 1.6;

  final List<String> availableFonts = [
    'Inter',
    'Roboto Mono',
    'JetBrains Mono',
    'Source Code Pro',
    'Merriweather',
    'Playfair Display',
    'Lora',
  ];

  SettingsProvider() {
    _loadSettings();
  }

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(_fontFamilyKey) ?? 'Inter';
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 18;
    _lineHeight = prefs.getDouble(_lineHeightKey) ?? 1.6;
    notifyListeners();
  }

  Future<void> setFontFamily(String fontFamily) async {
    if (_fontFamily != fontFamily) {
      _fontFamily = fontFamily;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontFamilyKey, fontFamily);
      notifyListeners();
    }
  }

  Future<void> setFontSize(double fontSize) async {
    if (_fontSize != fontSize) {
      _fontSize = fontSize;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, fontSize);
      notifyListeners();
    }
  }

  Future<void> setLineHeight(double lineHeight) async {
    if (_lineHeight != lineHeight) {
      _lineHeight = lineHeight;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_lineHeightKey, lineHeight);
      notifyListeners();
    }
  }
}
