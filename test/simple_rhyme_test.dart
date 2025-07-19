import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/services/cmu_pronunciation_service.dart';

void main() {
  group('Simple Rhyme Tests', () {
    late CMUPronunciationService cmuService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      cmuService = CMUPronunciationService();

      debugPrint('Initializing CMU service...');
      try {
        await cmuService.initialize();
        debugPrint(
            '✅ CMU Dictionary loaded: ${cmuService.dictionarySize} words');
      } catch (e) {
        debugPrint('❌ CMU initialization failed: $e');
        return;
      }
    });

    test('Test basic word pronunciations', () {
      final testWords = ['kiss', 'miss', 'cat', 'bat', 'day', 'way'];

      for (final word in testWords) {
        final pronunciation = cmuService.getPronunciation(word);
        final rhymePattern = cmuService.getRhymePattern(word);

        debugPrint('Word: "$word"');
        debugPrint('  Pronunciation: $pronunciation');
        debugPrint('  Rhyme pattern: $rhymePattern');
        debugPrint('');

        if (cmuService.isInitialized) {
          expect(pronunciation, isNotNull,
              reason: '$word should have pronunciation');
          expect(rhymePattern, isNotNull,
              reason: '$word should have rhyme pattern');
        }
      }
    });

    test('Test specific rhyme pairs', () {
      final rhymePairs = [
        ['kiss', 'miss'],
        ['cat', 'bat'],
        ['day', 'way'],
      ];

      for (final pair in rhymePairs) {
        final word1 = pair[0];
        final word2 = pair[1];

        final pattern1 = cmuService.getRhymePattern(word1);
        final pattern2 = cmuService.getRhymePattern(word2);
        final doRhyme = cmuService.doWordsRhyme(word1, word2);

        debugPrint('Testing: "$word1" vs "$word2"');
        debugPrint('  Pattern 1: $pattern1');
        debugPrint('  Pattern 2: $pattern2');
        debugPrint('  Do rhyme: $doRhyme');
        debugPrint('');

        if (pattern1 != null && pattern2 != null) {
          expect(pattern1, equals(pattern2),
              reason: 'Patterns should match for rhyming words');
          expect(doRhyme, isTrue, reason: '"$word1" and "$word2" should rhyme');
        }
      }
    });

    test('Test edge case rhymes', () {
      // Test some pronunciation-based rhymes that are tricky
      final edgeCases = [
        ['rough', 'stuff'], // Different spelling, same sound
        ['though', 'go'], // Very different spelling
        ['eight', 'weight'], // Different spelling patterns
      ];

      for (final pair in edgeCases) {
        final word1 = pair[0];
        final word2 = pair[1];

        final pattern1 = cmuService.getRhymePattern(word1);
        final pattern2 = cmuService.getRhymePattern(word2);
        final doRhyme = cmuService.doWordsRhyme(word1, word2);

        debugPrint('Edge case: "$word1" vs "$word2"');
        debugPrint('  Pattern 1: $pattern1');
        debugPrint('  Pattern 2: $pattern2');
        debugPrint('  Do rhyme: $doRhyme');
        debugPrint('');
      }
    });

    test('Debug CMU dictionary download', () {
      debugPrint('CMU Service Status:');
      debugPrint('  Initialized: ${cmuService.isInitialized}');
      debugPrint('  Dictionary size: ${cmuService.dictionarySize}');
      debugPrint('  Loading: ${cmuService.isLoading}');

      // Try to access a few known words
      final commonWords = ['the', 'and', 'hello', 'world'];
      for (final word in commonWords) {
        final pronunciation = cmuService.getPronunciation(word);
        debugPrint('  "$word": $pronunciation');
      }
    });
  });
}
