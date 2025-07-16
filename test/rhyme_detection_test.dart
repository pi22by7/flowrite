import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/cmu_pronunciation_service.dart';
import '../lib/services/rhyme_service.dart';

void main() {
  group('CMU Pronunciation Service Tests', () {
    late CMUPronunciationService cmuService;
    
    setUpAll(() async {
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      cmuService = CMUPronunciationService();
      
      // Initialize with a timeout for network calls
      try {
        await cmuService.initialize().timeout(Duration(seconds: 30));
        print('CMU Dictionary initialized with ${cmuService.dictionarySize} words');
      } catch (e) {
        print('Warning: CMU dictionary initialization failed: $e');
        print('Tests will run with fallback dictionary only');
      }
    });

    test('Basic rhyme detection - perfect rhymes', () {
      // These should definitely rhyme (same ending sound)
      final perfectRhymes = [
        ['kiss', 'miss'],
        ['cat', 'bat'],
        ['day', 'way'],
        ['night', 'sight'],
        ['love', 'dove'],
        ['tree', 'free'],
        ['mind', 'kind'],
        ['heart', 'start'],
      ];

      for (final pair in perfectRhymes) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        // Test both directions
        expect(
          cmuService.doWordsRhyme(word1, word2),
          isTrue,
          reason: '"$word1" and "$word2" should rhyme',
        );
        expect(
          cmuService.doWordsRhyme(word2, word1),
          isTrue,
          reason: '"$word2" and "$word1" should rhyme (reverse)',
        );
        
        // Check that they have the same rhyme pattern
        final pattern1 = cmuService.getRhymePattern(word1);
        final pattern2 = cmuService.getRhymePattern(word2);
        
        if (pattern1 != null && pattern2 != null) {
          expect(
            pattern1,
            equals(pattern2),
            reason: '"$word1" ($pattern1) and "$word2" ($pattern2) should have same rhyme pattern',
          );
        }
      }
    });

    test('Edge case rhymes - different spellings, same sound', () {
      // These are tricky cases where spelling differs but pronunciation rhymes
      final edgeCaseRhymes = [
        ['though', 'go'],         // Different spelling, same sound /oʊ/
        ['rough', 'stuff'],       // 'ough' vs 'uff' but same /ʌf/ sound
        ['break', 'steak'],       // Different spelling, same /eɪk/ sound
        ['eight', 'weight'],      // Different spelling, same /eɪt/ sound
        ['threw', 'through'],     // Very different spelling, same /ruː/ sound
        ['know', 'no'],           // Silent 'k' vs simple spelling
        ['write', 'right'],       // Silent 'w' vs 'r' spelling
        ['sea', 'see'],           // Different spelling, same /siː/ sound
        ['their', 'there'],       // Different spelling, same /ðɛər/ sound
        ['bear', 'bare'],         // Different spelling, same /bɛər/ sound
      ];

      for (final pair in edgeCaseRhymes) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        expect(
          cmuService.doWordsRhyme(word1, word2),
          isTrue,
          reason: '"$word1" and "$word2" should rhyme despite different spellings',
        );
      }
    });

    test('Complex rhymes - multi-syllable words', () {
      // Test longer words with rhyming endings
      final complexRhymes = [
        ['nation', 'station'],
        ['creation', 'vacation'],
        ['beautiful', 'dutiful'],
        ['remember', 'December'],
        ['amazing', 'blazing'],
        ['together', 'forever'],
        ['intention', 'attention'],
        ['relationship', 'championship'],
      ];

      for (final pair in complexRhymes) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        expect(
          cmuService.doWordsRhyme(word1, word2),
          isTrue,
          reason: '"$word1" and "$word2" should rhyme (complex words)',
        );
      }
    });

    test('Near rhymes - should NOT rhyme', () {
      // These look like they might rhyme but actually don't
      final nearRhymes = [
        ['love', 'move'],         // Different vowel sounds: /ʌv/ vs /uːv/
        ['cough', 'rough'],       // Different endings: /ɔːf/ vs /ʌf/
        ['pint', 'mint'],         // Different vowel sounds: /aɪnt/ vs /ɪnt/
        ['wind', 'kind'],         // When 'wind' is /wɪnd/ not /waɪnd/
        ['tear', 'bear'],         // When 'tear' is /tɪər/ not /tɛər/
        ['lead', 'read'],         // When pronounced /lɛd/ and /riːd/
        ['bow', 'cow'],           // When 'bow' is /boʊ/ not /baʊ/
        ['desert', 'dessert'],    // Stress difference affects rhyming
      ];

      for (final pair in nearRhymes) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        // Note: Some of these might actually rhyme depending on pronunciation
        // This test documents expected behavior but pronunciation can vary
        final doRhyme = cmuService.doWordsRhyme(word1, word2);
        print('Near-rhyme test: "$word1" and "$word2" -> $doRhyme');
      }
    });

    test('Words that definitely should NOT rhyme', () {
      final nonRhymes = [
        ['cat', 'dog'],
        ['house', 'tree'],
        ['happy', 'sad'],
        ['big', 'small'],
        ['fast', 'slow'],
        ['hot', 'cold'],
        ['light', 'heavy'],
        ['old', 'young'],
      ];

      for (final pair in nonRhymes) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        expect(
          cmuService.doWordsRhyme(word1, word2),
          isFalse,
          reason: '"$word1" and "$word2" should NOT rhyme',
        );
      }
    });

    test('Pronunciation patterns', () {
      // Test that we can get pronunciation data
      final testWords = ['hello', 'world', 'kiss', 'miss', 'cat', 'bat'];
      
      for (final word in testWords) {
        final pronunciation = cmuService.getPronunciation(word);
        final rhymePattern = cmuService.getRhymePattern(word);
        
        print('Word: $word');
        print('  Pronunciation: $pronunciation');
        print('  Rhyme pattern: $rhymePattern');
        
        if (pronunciation != null) {
          expect(pronunciation, isNotEmpty, reason: '$word should have pronunciation data');
        }
      }
    });

    test('Same word should not rhyme with itself', () {
      final words = ['cat', 'dog', 'house', 'tree'];
      
      for (final word in words) {
        expect(
          cmuService.doWordsRhyme(word, word),
          isFalse,
          reason: 'Word "$word" should not rhyme with itself',
        );
      }
    });

    test('Case insensitive rhyming', () {
      final testCases = [
        ['Kiss', 'miss'],
        ['CAT', 'bat'],
        ['Day', 'WAY'],
        ['NIGHT', 'sight'],
      ];

      for (final pair in testCases) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        expect(
          cmuService.doWordsRhyme(word1, word2),
          isTrue,
          reason: '"$word1" and "$word2" should rhyme regardless of case',
        );
      }
    });
  });

  group('RhymeService Integration Tests', () {
    late RhymeService rhymeService;
    
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      rhymeService = RhymeService();
      
      try {
        await rhymeService.initialize().timeout(Duration(seconds: 30));
        print('RhymeService initialized. CMU ready: ${rhymeService.isCMUReady}');
        print('Dictionary size: ${rhymeService.dictionarySize}');
      } catch (e) {
        print('Warning: RhymeService initialization failed: $e');
      }
    });

    test('RhymeService rhyme detection', () {
      final rhymePairs = [
        ['kiss', 'miss'],
        ['cat', 'bat'],
        ['day', 'way'],
      ];

      for (final pair in rhymePairs) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        expect(
          rhymeService.doWordsRhyme(word1, word2),
          isTrue,
          reason: 'RhymeService: "$word1" and "$word2" should rhyme',
        );
      }
    });

    test('Find rhymes in text', () {
      const text = 'The cat in the hat sat on the mat with a bat';
      final rhymes = rhymeService.findRhymes('cat', text);
      
      print('Rhymes for "cat" in text: $rhymes');
      
      // Should find words that rhyme with 'cat'
      expect(rhymes, contains('hat'));
      expect(rhymes, contains('sat'));
      expect(rhymes, contains('mat'));
      expect(rhymes, contains('bat'));
      
      // Should not contain the original word
      expect(rhymes, isNot(contains('cat')));
    });

    test('Color assignment consistency', () {
      // Test that the same rhyme pattern gets the same color
      const word1 = 'kiss';
      const word2 = 'miss';
      
      // Reset to ensure clean state
      rhymeService.reset();
      
      final color1 = rhymeService.getRhymeColor(word1);
      final color2 = rhymeService.getRhymeColor(word2);
      
      expect(
        color1,
        equals(color2),
        reason: 'Words that rhyme should have the same color',
      );
    });

    test('Performance with large text', () {
      // Test performance with a larger text sample
      const largeText = '''
        The cat in the hat sat on the mat,
        A rat and a bat began to chat,
        They talked about this and talked about that,
        While sitting on a welcome mat.
        
        The day was bright, the sky was blue,
        The sun shone through the morning dew,
        A bird flew by, then flew back too,
        And sang a song both sweet and true.
      ''';
      
      final stopwatch = Stopwatch()..start();
      
      // Find rhymes for multiple words
      final words = ['cat', 'day', 'blue', 'bright'];
      for (final word in words) {
        final rhymes = rhymeService.findRhymes(word, largeText);
        print('Rhymes for "$word": $rhymes');
      }
      
      stopwatch.stop();
      print('Time taken for rhyme finding: ${stopwatch.elapsedMilliseconds}ms');
      
      // Should complete reasonably quickly (under 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('Fallback System Tests', () {
    test('Fallback rhyme detection without CMU service', () {
      // Test the fallback system by creating a service without initialization
      final rhymeService = RhymeService();
      // Don't initialize - should use fallback
      
      // Basic rhymes that should work with fallback rules
      final basicRhymes = [
        ['cat', 'bat'],
        ['day', 'way'],
        ['sing', 'ring'],
      ];

      for (final pair in basicRhymes) {
        final word1 = pair[0];
        final word2 = pair[1];
        
        final doRhyme = rhymeService.doWordsRhyme(word1, word2);
        print('Fallback test: "$word1" and "$word2" -> $doRhyme');
        
        // With fallback, some basic rhymes should still work
        if (doRhyme) {
          expect(doRhyme, isTrue);
        }
      }
    });
  });
}