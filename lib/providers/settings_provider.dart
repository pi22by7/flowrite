import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _fontFamilyKey = 'fontFamily';
  static const String _fontSizeKey = 'fontSize';
  static const String _lineHeightKey = 'lineHeight';
  static const String _showSyllablesKey = 'showSyllables';
  static const String _showRhymesKey = 'showRhymes';
  static const String _focusModeKey = 'focusMode';

  bool _showSyllables = true;
  bool _showRhymes = true;
  bool _focusMode = false;

  bool get showSyllables => _showSyllables;
  bool get showRhymes => _showRhymes;
  bool get focusMode => _focusMode;

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
    'Fascinate',
  ];

  // Font personality labels for helping writers choose
  final Map<String, String> fontPersonalities = {
    'Inter': 'Modern',
    'Roboto Mono': 'Focused',
    'JetBrains Mono': 'Technical',
    'Source Code Pro': 'Precise',
    'Merriweather': 'Classic',
    'Playfair Display': 'Elegant',
    'Lora': 'Poetic',
    'Fascinate': 'Playful',
  };

  // Get personality label for a font
  String getFontPersonality(String fontFamily) {
    return fontPersonalities[fontFamily] ?? 'Custom';
  }

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
    _showSyllables = prefs.getBool(_showSyllablesKey) ?? true;
    _showRhymes = prefs.getBool(_showRhymesKey) ?? true;
    _focusMode = prefs.getBool(_focusModeKey) ?? false;
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

  Future<void> setShowSyllables(bool value) async {
    if (_showSyllables != value) {
      _showSyllables = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showSyllablesKey, value);
      notifyListeners();
    }
  }

  Future<void> setShowRhymes(bool value) async {
    if (_showRhymes != value) {
      _showRhymes = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showRhymesKey, value);
      notifyListeners();
    }
  }

  Future<void> setFocusMode(bool value) async {
    if (_focusMode != value) {
      _focusMode = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_focusModeKey, value);
      notifyListeners();
    }
  }
}
