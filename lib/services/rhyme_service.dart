// lib/services/rhyme_service.dart
import 'package:flutter/material.dart';

class RhymeService {
  final Map<String, Color> _rhymeColors = {};
  final List<Color> _predefinedColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];
  int _colorIndex = 0;

  Color _getNextColor() {
    if (_colorIndex >= _predefinedColors.length) {
      _colorIndex = 0;
    }
    return _predefinedColors[_colorIndex++];
  }

  String _getRhymeKey(String word) {
    if (word.length < 3) return word;
    return word.substring(word.length - 3);
  }

  Color getRhymeColor(String word) {
    if (word.isEmpty) return Colors.black;

    final key = _getRhymeKey(word);
    if (!_rhymeColors.containsKey(key)) {
      _rhymeColors[key] = _getNextColor();
    }
    return _rhymeColors[key]!;
  }

  void reset() {
    _rhymeColors.clear();
    _colorIndex = 0;
  }
}
