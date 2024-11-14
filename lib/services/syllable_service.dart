// lib/services/syllable_service.dart
class SyllableService {
  int countSyllables(String word) {
    if (word.isEmpty) return 0;

    word = word.toLowerCase();
    int count = 0;
    bool isPreviousVowel = false;

    for (int i = 0; i < word.length; i++) {
      bool isVowel = _isVowel(word[i]);

      if (isVowel && !isPreviousVowel) {
        count++;
      }

      isPreviousVowel = isVowel;
    }

    // Handle silent e at the end
    if (word.length > 1 && word.endsWith('e')) {
      count--;
    }

    return count > 0 ? count : 1;
  }

  bool _isVowel(String char) {
    return 'aeiou'.contains(char);
  }
}
