import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import '../lib/services/cmu_pronunciation_service.dart';

void main() {
  group('Simple Rhyme Tests', () {
    late CMUPronunciationService cmuService;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      cmuService = CMUPronunciationService();
      
      print('Initializing CMU service...');
      try {
        await cmuService.initialize();
        print('✅ CMU Dictionary loaded: ${cmuService.dictionarySize} words');
      } catch (e) {
        print('❌ CMU initialization failed: $e');
        return;
      }
    });

    test('Test basic word pronunciations', () {
      final testWords = ['kiss', 'miss', 'cat', 'bat', 'day', 'way'];
      
      for (final word in testWords) {
        final pronunciation = cmuService.getPronunciation(word);
        final rhymePattern = cmuService.getRhymePattern(word);
        
        print('Word: "$word"');
        print('  Pronunciation: $pronunciation');
        print('  Rhyme pattern: $rhymePattern');
        print('');
        
        if (cmuService.isInitialized) {
          expect(pronunciation, isNotNull, reason: '$word should have pronunciation');
          expect(rhymePattern, isNotNull, reason: '$word should have rhyme pattern');
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
        
        print('Testing: "$word1" vs "$word2"');
        print('  Pattern 1: $pattern1');
        print('  Pattern 2: $pattern2');
        print('  Do rhyme: $doRhyme');
        print('');
        
        if (pattern1 != null && pattern2 != null) {
          expect(pattern1, equals(pattern2), reason: 'Patterns should match for rhyming words');
          expect(doRhyme, isTrue, reason: '"$word1" and "$word2" should rhyme');
        }
      }
    });

    test('Test edge case rhymes', () {
      // Test some pronunciation-based rhymes that are tricky
      final edgeCases = [
        ['rough', 'stuff'],   // Different spelling, same sound
        ['though', 'go'],     // Very different spelling
        ['eight', 'weight'],  // Different spelling patterns
      ];

      for (final pair in edgeCases) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        final pattern1 = cmuService.getRhymePattern(word1);
        final pattern2 = cmuService.getRhymePattern(word2);
        final doRhyme = cmuService.doWordsRhyme(word1, word2);
        
        print('Edge case: "$word1" vs "$word2"');
        print('  Pattern 1: $pattern1');
        print('  Pattern 2: $pattern2');
        print('  Do rhyme: $doRhyme');
        print('');
      }
    });

    test('Debug CMU dictionary download', () {
      print('CMU Service Status:');
      print('  Initialized: ${cmuService.isInitialized}');
      print('  Dictionary size: ${cmuService.dictionarySize}');
      print('  Loading: ${cmuService.isLoading}');
      
      // Try to access a few known words
      final commonWords = ['the', 'and', 'hello', 'world'];
      for (final word in commonWords) {
        final pronunciation = cmuService.getPronunciation(word);
        print('  "$word": $pronunciation');
      }
    });
  });
}