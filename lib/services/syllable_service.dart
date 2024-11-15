// lib/services/syllable_service.dart
class SyllableService {
  static final List<String> _subSyllables = [
    'cial', 'tial', 'cius', 'gious', 'geous', 'sion', 'tion',
    'quiet', 'iet', 'ian', 'ua', 'ia'
  ];

  static final List<String> _addSyllables = [
    'io', 'ia', 'ii', 'io', 'eo', 'oo',
    'ye', 'es', 'ed', 'ing',
    'ism', 'ist', 'ity', 'en', 'er', 'ese',
    'ful', 'gent', 'ent', 'ness',
  ];

  static final RegExp _consonantCluster = RegExp(r'[bcdfghjklmnpqrstvwxz]{2,}');
  static final RegExp _vowelCluster = RegExp(r'[aeiou]{2,}');

  int countSyllablesInText(String text) {
    if (text.isEmpty) return 0;

    // Split text into words and count syllables for each word
    return text
        .split(RegExp(r'[\s\n]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => countSyllables(_cleanWord(word)))
        .fold(0, (sum, count) => sum + count);
  }

  String _cleanWord(String word) {
    // Remove punctuation and special characters
    return word.toLowerCase().replaceAll(RegExp(r'[^a-z\-]'), '');
  }

  int countSyllables(String word) {
    if (word.isEmpty) return 0;
    word = _cleanWord(word);

    if (word.isEmpty) return 0;
    // Validate input
    if (!_isValidWord(word)) return 0;

    // Clean the word
    word = word.toLowerCase().trim();
    word = word.replaceAll(RegExp(r'[^a-z\-]'), '');

    if (word.isEmpty) return 0;

    // Handle compound words first
    if (_isCompoundWord(word)) {
      final compoundCount = _handleCompoundWord(word);
      if (compoundCount > 0) return compoundCount;
    }

    // Handle numbers
    final numberCount = _handleNumber(word);
    if (numberCount > 0) return numberCount;

    // Handle special cases
    if (_specialCases.containsKey(word)) {
      return _specialCases[word]!;
    }

    // Handle exceptions
    final exceptionCount = _handleExceptions(word);
    if (exceptionCount > 0) return exceptionCount;

    // If no vowel sounds, return 1
    if (!_hasVowelSound(word)) return 1;

    int count = 0;
    bool isPreviousVowel = false;

    // Handle prefixes and suffixes
    for (var prefix in _prefixes.keys) {
      if (word.startsWith(prefix)) {
        count += _prefixes[prefix]!;
        word = word.substring(prefix.length);
        break;
      }
    }

    for (var suffix in _suffixes.keys) {
      if (word.endsWith(suffix)) {
        count += _suffixes[suffix]!;
        word = word.substring(0, word.length - suffix.length);
        break;
      }
    }

    // Count basic syllables
    for (int i = 0; i < word.length; i++) {
      bool isVowel = _isVowel(word[i]);
      if (isVowel && !isPreviousVowel) {
        count++;
      }
      isPreviousVowel = isVowel;
    }

    // Handle special patterns
    for (String pattern in _subSyllables) {
      if (word.contains(pattern)) {
        count--;
      }
    }

    for (String pattern in _addSyllables) {
      if (word.contains(pattern)) {
        count++;
      }
    }

    // Handle silent e and -le endings
    if (word.length > 2) {
      if (word.endsWith('e') && !word.endsWith('le')) {
        if (!_isVowel(word[word.length - 2])) {
          count--;
        }
      } else if (word.endsWith('le') && !_isVowel(word[word.length - 3])) {
        count++;
      }
    }

    // Handle consonant and vowel clusters
    int consonantClusters = _consonantCluster.allMatches(word).length;
    count += (consonantClusters > 0) ? consonantClusters ~/ 2 : 0;

    for (Match match in _vowelCluster.allMatches(word)) {
      String cluster = match.group(0)!;
      count -= (cluster.length - 1) ~/ 2;
    }

    return count > 0 ? count : 1;
  }

  bool _isVowel(String char) {
    return 'aeiouy'.contains(char);
  }

  static const Map<String, int> _specialCases = {
    'does': 1,
    'area': 2,
    'idea': 3,
    'real': 2,
    'being': 2,
    'doing': 2,
    'going': 2,
    'quiet': 2,
    'science': 2,
    'ocean': 2,
    'create': 2,
    'poem': 2,
    'poet': 2,
    'poetry': 3,
    'every': 3,
    'everything': 4,
    'beautiful': 3,
    'naturally': 4,
    'business': 2,
    'different': 3,
    'interesting': 4,
    'evening': 3,
    'experience': 4,
    'family': 3,
    'generally': 4,
    'government': 3,
    'history': 3,
    'library': 3,
    'literature': 4,
    'memory': 3,
    'mystery': 3,
    'natural': 3,
    'regular': 3,
    'several': 3,
    'temperature': 4,
    'vegetable': 4,
  };

  static const Map<String, int> _prefixes = {
    'anti': 2,
    'auto': 2,
    'bio': 2,
    'counter': 2,
    'dis': 1,
    'en': 1,
    'fore': 1,
    'geo': 2,
    'hyper': 2,
    'inter': 2,
    'intra': 2,
    'macro': 2,
    'micro': 2,
    'mid': 1,
    'mis': 1,
    'mono': 2,
    'multi': 2,
    'neo': 2,
    'non': 1,
    'omni': 2,
    'over': 2,
    'poly': 2,
    'post': 1,
    'pre': 1,
    'pro': 1,
    're': 1,
    'semi': 2,
    'sub': 1,
    'super': 2,
    'trans': 1,
    'tri': 1,
    'ultra': 2,
    'un': 1,
    'under': 2,
  };

  static const Map<String, int> _suffixes = {
  'able': 2,
  'ably': 2,
  'age': 1,
  'al': 1,
  'ally': 2,
  'ance': 1,
  'ant': 1,
  'ary': 2,
  'ation': 2,
  'ative': 2,
  'ed': 1,
  'en': 1,
  'ence': 1,
  'ent': 1,
  'er': 1,
  'ery': 2,
  'es': 1,
  'est': 1,
  'ful': 1,
  'ial': 2,
  'ible': 2,
  'ibly': 2,
  'ic': 1,
  'ical': 2,
  'ically': 3,
  'ice': 1,
  'ify': 2,
  'ing': 1,
  'ion': 1,
  'ious': 2,
  'ish': 1,
  'ism': 2,
  'ist': 1,
  'ity': 2,
  'ive': 1,
  'ize': 1,
  'less': 1,
  'ly': 1,
  'ment': 1,
  'ness': 1,
  'or': 1,
  'ous': 1,
  'ship': 1,
  'ty': 1,
  'ure': 1,
  'ward': 1,
  'wards': 1,
  'wise': 1,
  'y': 1,
    // ... continuing from previous suffixes
  };

  // Add helper methods for better accuracy
  bool _isConsonant(String char) {
    return !_isVowel(char);
  }

  bool _hasVowelSound(String word) {
    for (int i = 0; i < word.length; i++) {
      if (_isVowel(word[i])) return true;
      if (word[i] == 'y' && i > 0 && _isConsonant(word[i - 1])) return true;
    }
    return false;
  }

  bool _isCompoundWord(String word) {
    // Check for common compound word separators
    return word.contains('-') ||
        word.contains('/') ||
        _commonCompoundWords.contains(word);
  }

  // Add common compound words that might need special handling
  static const Set<String> _commonCompoundWords = {
    'somewhere',
    'anymore',
    'anyone',
    'everybody',
    'everything',
    'somewhat',
    'otherwise',
    'whatever',
    'whenever',
    'wherever',
    'nonetheless',
    'nowadays',
    'meanwhile',
    'without',
    'within',
    'throughout',
  };

  // Add method to handle compound words
  int _handleCompoundWord(String word) {
    if (word.contains('-')) {
      return word.split('-')
          .map((part) => countSyllables(part))
          .reduce((a, b) => a + b);
    }
    return 0; // Not a compound word
  }

  // Add method to handle numbers
  int _handleNumber(String word) {
    // Handle common number words
    const Map<String, int> numberSyllables = {
      'zero': 2,
      'one': 1,
      'two': 1,
      'three': 1,
      'four': 1,
      'five': 1,
      'six': 1,
      'seven': 2,
      'eight': 1,
      'nine': 1,
      'ten': 1,
      'eleven': 3,
      'twelve': 1,
      'thirteen': 2,
      'fourteen': 2,
      'fifteen': 2,
      'sixteen': 2,
      'seventeen': 3,
      'eighteen': 2,
      'nineteen': 2,
      'twenty': 2,
      'thirty': 2,
      'forty': 2,
      'fifty': 2,
      'sixty': 2,
      'seventy': 3,
      'eighty': 2,
      'ninety': 2,
      'hundred': 2,
      'thousand': 2,
      'million': 3,
      'billion': 2,
      'trillion': 2,
    };

    return numberSyllables[word] ?? 0;
  }

  // Add method to validate input
  bool _isValidWord(String word) {
    return word.isNotEmpty &&
        RegExp(r'^[a-zA-Z\-]+$').hasMatch(word);
  }

  // Add method for better accuracy with common exceptions
  int _handleExceptions(String word) {
    // Handle words ending in 'sm'
    if (word.endsWith('sm') && word.length > 3) {
      return countSyllables(word.substring(0, word.length - 2)) + 1;
    }

    // Handle words ending in 'thm'
    if (word.endsWith('thm')) {
      return countSyllables(word.substring(0, word.length - 3)) + 1;
    }

    return 0; // No exception found
  }

  // Add method to get syllable stress pattern
  List<bool> getStressPattern(String word) {
    final syllableCount = countSyllables(word);
    if (syllableCount <= 1) return [true];

    // Basic stress patterns for English words
    if (syllableCount == 2) {
      return word.endsWith('ing') || word.endsWith('ed')
          ? [true, false]
          : [false, true];
    }

    // For longer words, implement more complex stress patterns
    return List.generate(syllableCount, (index) => index == 0);
  }
}
