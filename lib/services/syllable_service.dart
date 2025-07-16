import 'package:english_words/english_words.dart' as english_words;

class SyllableService {
  // Cache for performance
  final Map<String, int> _syllableCache = {};
  
  // Regex patterns for word cleaning and validation
  static final RegExp _wordPattern = RegExp(r"[a-zA-Z\-']+");
  static final RegExp _cleanPattern = RegExp(r'[^a-zA-Z]');

  int countSyllablesInText(String text) {
    if (text.isEmpty) return 0;

    // Extract words using regex pattern matching
    final words = _wordPattern.allMatches(text).map((match) => match.group(0)!);
    
    return words
        .map((word) => countSyllables(word))
        .fold(0, (sum, count) => sum + count);
  }

  String _cleanWord(String word) {
    // Remove punctuation and special characters, keep hyphens and apostrophes
    return word.toLowerCase().replaceAll(_cleanPattern, '');
  }

  int countSyllables(String word) {
    if (word.isEmpty) return 0;
    
    final cleanedWord = _cleanWord(word);
    if (cleanedWord.isEmpty) return 0;
    
    // Check cache first for performance
    if (_syllableCache.containsKey(cleanedWord)) {
      return _syllableCache[cleanedWord]!;
    }
    
    int result;
    
    try {
      // Use english_words package for accurate syllable counting
      result = english_words.syllables(cleanedWord);
    } catch (e) {
      // Fallback to simple counting for words with non-alphabetic characters
      result = _fallbackSyllableCount(cleanedWord);
    }
    
    // Cache the result
    _syllableCache[cleanedWord] = result;
    return result;
  }

  /// Fallback syllable counting for edge cases
  int _fallbackSyllableCount(String word) {
    if (word.isEmpty) return 0;
    
    // Handle compound words with hyphens
    if (word.contains('-')) {
      return word.split('-')
          .map((part) => countSyllables(part))
          .fold(0, (sum, count) => sum + count);
    }
    
    // Simple vowel-based counting as last resort
    int count = 0;
    bool previousWasVowel = false;
    
    for (int i = 0; i < word.length; i++) {
      final isVowel = 'aeiouy'.contains(word[i].toLowerCase());
      if (isVowel && !previousWasVowel) {
        count++;
      }
      previousWasVowel = isVowel;
    }
    
    // Handle silent 'e'
    if (word.length > 1 && word.toLowerCase().endsWith('e')) {
      final secondLast = word[word.length - 2].toLowerCase();
      if (!'aeiouy'.contains(secondLast)) {
        count = count > 1 ? count - 1 : 1;
      }
    }
    
    return count > 0 ? count : 1;
  }
  

  /// Clear the syllable cache to free memory
  void clearCache() {
    _syllableCache.clear();
  }




  /// Get basic stress pattern for a word (simplified heuristics)
  List<bool> getStressPattern(String word) {
    final syllableCount = countSyllables(word);
    if (syllableCount <= 1) return [true];

    // Basic stress patterns for English words
    if (syllableCount == 2) {
      // Most 2-syllable nouns stress the first syllable
      // Most 2-syllable verbs stress the second syllable
      // This is a simplification - ideally would need POS tagging
      return word.endsWith('ing') || word.endsWith('ed') || word.endsWith('er')
          ? [true, false]
          : [false, true];
    }

    // For longer words, typically stress first syllable (oversimplified)
    return List.generate(syllableCount, (index) => index == 0);
  }
}
