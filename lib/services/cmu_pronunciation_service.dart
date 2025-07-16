import 'dart:convert';
import 'package:flutter/services.dart';

class CMUPronunciationService {
  static const String _assetPath = 'assets/cmudict.dict';
  
  final Map<String, List<String>> _pronunciationDict = {};
  bool _isInitialized = false;
  bool _isLoading = false;

  /// Initialize the pronunciation dictionary
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    
    _isLoading = true;
    try {
      await _loadFromAssets();
      _isInitialized = true;
    } catch (e) {
      print('Error loading CMU dictionary from assets: $e');
      // Fall back to a minimal set for basic functionality
      _loadMinimalDictionary();
      _isInitialized = true;
    } finally {
      _isLoading = false;
    }
  }

  /// Load dictionary from bundled assets
  Future<void> _loadFromAssets() async {
    try {
      print('Loading CMU pronunciation dictionary from assets...');
      final String content = await rootBundle.loadString(_assetPath);
      final lines = LineSplitter.split(content);
      _parseDictionary(lines);
      
      print('CMU dictionary loaded: ${_pronunciationDict.length} entries');
    } catch (e) {
      print('Error loading CMU dictionary from assets: $e');
      rethrow;
    }
  }

  /// Parse the CMU dictionary format
  void _parseDictionary(Iterable<String> lines) {
    _pronunciationDict.clear();
    
    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith(';;;')) {
        continue; // Skip comments and empty lines
      }
      
      final parts = line.split(' '); // Space separator
      if (parts.length >= 2) {
        final word = parts[0].toLowerCase();
        final phonemes = parts.sublist(1); // All parts after the word are phonemes
        
        // Handle multiple pronunciations (e.g., TOMATO(2))
        final cleanWord = word.replaceAll(RegExp(r'\(\d+\)$'), '');
        
        if (!_pronunciationDict.containsKey(cleanWord)) {
          _pronunciationDict[cleanWord] = phonemes;
        }
        // For multiple pronunciations, we keep the first one (most common)
      }
    }
  }

  /// Load a minimal dictionary for fallback
  void _loadMinimalDictionary() {
    _pronunciationDict.addAll({
      'kiss': ['K', 'IH1', 'S'],
      'miss': ['M', 'IH1', 'S'],
      'hit': ['HH', 'IH1', 'T'],
      'sit': ['S', 'IH1', 'T'],
      'cat': ['K', 'AE1', 'T'],
      'bat': ['B', 'AE1', 'T'],
      'day': ['D', 'EY1'],
      'way': ['W', 'EY1'],
      'play': ['P', 'L', 'EY1'],
      'say': ['S', 'EY1'],
    });
  }

  /// Get pronunciation for a word
  List<String>? getPronunciation(String word) {
    if (!_isInitialized) return null;
    
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return _pronunciationDict[cleanWord];
  }

  /// Extract rhyme pattern from phonemes (from primary stress to end)
  String? getRhymePattern(String word) {
    final phonemes = getPronunciation(word);
    if (phonemes == null || phonemes.isEmpty) return null;
    
    // Find the vowel with primary stress (ends with '1')
    int stressIndex = -1;
    for (int i = 0; i < phonemes.length; i++) {
      if (phonemes[i].endsWith('1')) {
        stressIndex = i;
        break;
      }
    }
    
    // If no primary stress found, look for secondary stress ('2')
    if (stressIndex == -1) {
      for (int i = 0; i < phonemes.length; i++) {
        if (phonemes[i].endsWith('2')) {
          stressIndex = i;
          break;
        }
      }
    }
    
    // If still no stress found, use the last vowel
    if (stressIndex == -1) {
      for (int i = phonemes.length - 1; i >= 0; i--) {
        if (_isVowelPhoneme(phonemes[i])) {
          stressIndex = i;
          break;
        }
      }
    }
    
    // Return phonemes from stress point to end
    if (stressIndex >= 0) {
      final rhymePhonemes = phonemes.sublist(stressIndex);
      // Remove stress markers for comparison
      return rhymePhonemes
          .map((p) => p.replaceAll(RegExp(r'[012]$'), ''))
          .join(' ');
    }
    
    return null;
  }

  /// Check if two words rhyme based on their phoneme patterns
  bool doWordsRhyme(String word1, String word2) {
    final pattern1 = getRhymePattern(word1);
    final pattern2 = getRhymePattern(word2);
    
    return pattern1 != null && 
           pattern2 != null && 
           pattern1 == pattern2 &&
           word1.toLowerCase() != word2.toLowerCase();
  }

  /// Find all rhymes for a word from a list of words
  List<String> findRhymes(String targetWord, List<String> words) {
    final targetPattern = getRhymePattern(targetWord);
    if (targetPattern == null) return [];
    
    return words
        .where((word) => doWordsRhyme(targetWord, word))
        .toList();
  }

  /// Check if a phoneme is a vowel
  bool _isVowelPhoneme(String phoneme) {
    final vowelPhonemes = {
      'AA', 'AE', 'AH', 'AO', 'AW', 'AY',
      'EH', 'ER', 'EY',
      'IH', 'IY',
      'OW', 'OY',
      'UH', 'UW'
    };
    
    final cleanPhoneme = phoneme.replaceAll(RegExp(r'[012]$'), '');
    return vowelPhonemes.contains(cleanPhoneme);
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if the service is currently loading
  bool get isLoading => _isLoading;

  /// Get the number of words in the dictionary
  int get dictionarySize => _pronunciationDict.length;

  /// Clear the dictionary (useful for testing)
  void clearDictionary() {
    _pronunciationDict.clear();
    _isInitialized = false;
  }
}