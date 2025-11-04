import 'package:flutter/material.dart';
import 'cmu_pronunciation_service.dart';

class RhymeService {
  final Map<String, Color> _rhymeColors = {};
  final Map<String, String> _rhymePatternCache = {};
  final CMUPronunciationService _cmuService = CMUPronunciationService();
  bool _isInitialized = false;
  
  
  // Watercolor-style soft, pastel colors for rhyming words
  final List<Color> _predefinedColors = [
    const Color(0xFF9BB8CD), // Soft periwinkle blue
    const Color(0xFFE8B4B8), // Soft rose
    const Color(0xFFA8D5BA), // Soft sage green
    const Color(0xFFD4B5D3), // Soft lavender
    const Color(0xFFF4C7AB), // Soft peach
    const Color(0xFF89CFF0), // Soft baby blue
    const Color(0xFFF4C2C2), // Soft blush pink
    const Color(0xFFB4A7D6), // Soft periwinkle purple
    const Color(0xFFFADDA0), // Soft cream yellow
    const Color(0xFFB5E7E3), // Soft mint
    const Color(0xFFFFB5A7), // Soft coral
    const Color(0xFFD4E8C1), // Soft pistachio
    const Color(0xFFE6BDEA), // Soft orchid
    const Color(0xFFD7C4BB), // Soft taupe
    const Color(0xFFC5D5E4), // Soft powder blue
  ];
  int _colorIndex = 0;

  Color _getNextColor() {
    if (_colorIndex >= _predefinedColors.length) {
      _colorIndex = 0;
    }
    return _predefinedColors[_colorIndex++];
  }

  /// Initialize the CMU pronunciation service
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _cmuService.initialize();
    _isInitialized = true;
  }
  
  /// Generate rhyme key using CMU pronunciation data
  String _getRhymeKey(String word) {
    if (word.isEmpty) return '';
    
    // Clean word: remove punctuation, convert to lowercase
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (cleanWord.isEmpty) return '';
    
    // Check cache first
    if (_rhymePatternCache.containsKey(cleanWord)) {
      return _rhymePatternCache[cleanWord]!;
    }
    
    String rhymeKey;
    
    // Try CMU pronunciation first
    if (_isInitialized && _cmuService.isInitialized) {
      final rhymePattern = _cmuService.getRhymePattern(cleanWord);
      if (rhymePattern != null) {
        rhymeKey = rhymePattern;
      } else {
        // Fallback to rule-based approach
        rhymeKey = _generateFallbackRhymePattern(cleanWord);
      }
    } else {
      // Fallback to rule-based approach if CMU service not ready
      rhymeKey = _generateFallbackRhymePattern(cleanWord);
    }
    
    // Cache the result
    _rhymePatternCache[cleanWord] = rhymeKey;
    return rhymeKey;
  }
  
  /// Fallback rhyme pattern generation for words not in CMU dictionary
  String _generateFallbackRhymePattern(String word) {
    if (word.length <= 2) return word;
    
    // Handle common rhyme endings first
    final rhymeEnding = _getCommonRhymeEnding(word);
    if (rhymeEnding.isNotEmpty) {
      return rhymeEnding;
    }
    
    // For words ending in consonant + vowel + consonant (like 'kiss', 'miss')
    if (word.length >= 3) {
      final last3 = word.substring(word.length - 3);
      final pattern = _getVowelConsonantPattern(last3);
      if (pattern.isNotEmpty) {
        return pattern;
      }
    }
    
    // Fall back to last 2-3 characters with vowel normalization
    final ending = word.length > 3 ? word.substring(word.length - 3) : word;
    return _normalizeVowelSounds(ending);
  }
  
  /// Get common rhyme endings (like -ing, -tion, -ly, etc.)
  String _getCommonRhymeEnding(String word) {
    final commonEndings = {
      // 3+ character endings
      'tion': 'TION', 'sion': 'TION', 'ght': 'GHT', 'ing': 'ING',
      'ness': 'NESS', 'ment': 'MENT', 'able': 'ABLE', 'ible': 'ABLE',
      'ough': 'OUGH', 'augh': 'OUGH', 'eigh': 'EY', 'ight': 'ITE',
      
      // 2 character endings  
      'ly': 'LY', 'ed': 'ED', 'er': 'ER', 'le': 'EL', 'al': 'AL',
      'ic': 'IC', 'ty': 'TY', 'ry': 'RY', 'ny': 'NY', 'my': 'MY',
      'sy': 'SY', 'py': 'PY', 'fy': 'FY', 'by': 'BY', 'dy': 'DY',
      
      // Vowel endings
      'ay': 'AY', 'ey': 'EY', 'oy': 'OY', 'uy': 'UY',
      'aw': 'AW', 'ew': 'EW', 'ow': 'OW', 'ue': 'UE',
    };
    
    for (final ending in commonEndings.keys) {
      if (word.endsWith(ending)) {
        return commonEndings[ending]!;
      }
    }
    
    return '';
  }
  
  /// Analyze vowel-consonant patterns for better rhyme matching
  String _getVowelConsonantPattern(String segment) {
    if (segment.length < 2) return '';
    
    final vowels = 'aeiou';
    final pattern = segment.split('').map((char) => 
        vowels.contains(char) ? 'V' : 'C').join('');
    
    // For patterns like CVC (consonant-vowel-consonant): miss, kiss, hit, sit
    if (pattern == 'CVC') {
      final vowel = segment[1];
      final consonant = segment[2];
      // Group similar vowel sounds and ending consonants
      final vowelGroup = _getVowelGroup(vowel);
      final consonantGroup = _getConsonantGroup(consonant);
      return '${vowelGroup}_$consonantGroup';
    }
    
    // For patterns like VCC: ask, mask
    if (pattern == 'VCC') {
      final vowel = segment[0];
      final consonants = segment.substring(1);
      return '${_getVowelGroup(vowel)}_$consonants';
    }
    
    return '';
  }
  
  /// Group similar vowel sounds together
  String _getVowelGroup(String vowel) {
    switch (vowel) {
      case 'a': return 'A';
      case 'e': return 'E'; 
      case 'i': return 'I';
      case 'o': return 'O';
      case 'u': return 'U';
      default: return vowel.toUpperCase();
    }
  }
  
  /// Group similar consonant sounds together
  String _getConsonantGroup(String consonant) {
    final groups = {
      // Sibilants
      's': 'S', 'z': 'S', 'x': 'S',
      // Stops
      'p': 'P', 'b': 'P', 't': 'T', 'd': 'T', 'k': 'K', 'g': 'K',
      // Nasals  
      'm': 'M', 'n': 'N',
      // Liquids
      'l': 'L', 'r': 'R',
      // Fricatives
      'f': 'F', 'v': 'F', 'th': 'TH',
    };
    
    return groups[consonant] ?? consonant.toUpperCase();
  }
  
  /// Normalize vowel sounds for better rhyme matching
  String _normalizeVowelSounds(String ending) {
    // Replace similar sounding vowel combinations
    return ending
        .replaceAll('ee', 'E')
        .replaceAll('ea', 'E') 
        .replaceAll('ie', 'E')
        .replaceAll('oo', 'U')
        .replaceAll('ou', 'U')
        .replaceAll('ow', 'O')
        .replaceAll('ay', 'A')
        .replaceAll('ai', 'A');
  }

  Color getRhymeColor(String word) {
    if (word.isEmpty) return Colors.black;

    final key = _getRhymeKey(word);
    if (key.isEmpty) return Colors.black;
    
    if (!_rhymeColors.containsKey(key)) {
      _rhymeColors[key] = _getNextColor();
    }
    return _rhymeColors[key]!;
  }

  void reset() {
    _rhymeColors.clear();
    _colorIndex = 0;
  }
  
  /// Clear caches to free memory
  void clearCache() {
    _rhymePatternCache.clear();
    reset();
  }
  
  /// Check if two words rhyme using CMU pronunciation data
  bool doWordsRhyme(String word1, String word2) {
    if (word1.isEmpty || word2.isEmpty) return false;
    
    // Try CMU pronunciation service first
    if (_isInitialized && _cmuService.isInitialized) {
      return _cmuService.doWordsRhyme(word1, word2);
    }
    
    // Fallback to pattern matching
    final key1 = _getRhymeKey(word1);
    final key2 = _getRhymeKey(word2);
    
    return key1.isNotEmpty && key2.isNotEmpty && key1 == key2;
  }
  
  /// Get all words that rhyme with a given word from a text
  List<String> findRhymes(String targetWord, String text) {
    final words = RegExp(r'[a-zA-Z]+').allMatches(text)
        .map((match) => match.group(0)!)
        .where((word) => word.toLowerCase() != targetWord.toLowerCase())
        .toSet();
    
    // Try CMU pronunciation service first
    if (_isInitialized && _cmuService.isInitialized) {
      return _cmuService.findRhymes(targetWord, words.toList());
    }
    
    // Fallback to pattern matching
    final targetKey = _getRhymeKey(targetWord);
    if (targetKey.isEmpty) return [];
    
    return words
        .where((word) => _getRhymeKey(word) == targetKey)
        .toList();
  }
  
  /// Get initialization status
  bool get isInitialized => _isInitialized;
  
  /// Get CMU service status
  bool get isCMUReady => _cmuService.isInitialized;
  
  /// Get CMU dictionary size
  int get dictionarySize => _cmuService.dictionarySize;
}
