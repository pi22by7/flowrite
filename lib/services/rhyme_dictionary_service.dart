import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RhymeResult {
  final String word;
  final int score;
  final int flags;
  final int syllables;

  RhymeResult({
    required this.word,
    required this.score,
    required this.flags,
    required this.syllables,
  });

  factory RhymeResult.fromJson(Map<String, dynamic> json) {
    return RhymeResult(
      word: json['word'] ?? '',
      score: _parseInt(json['score']),
      flags: _parseInt(json['flags']),
      syllables: _parseInt(json['syllables']),
    );
  }
  
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class RhymeDictionaryService {
  static const String _baseUrl = 'https://rhymebrain.com';
  static const String _userAgent = 'Flowrite/3.3.2 (https://flowrite.app)';
  
  final http.Client _client;

  RhymeDictionaryService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<RhymeResult>> getRhymes(String word, {int maxResults = 20}) async {
    if (word.trim().isEmpty) return [];
    
    final cleanWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (cleanWord.isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/talk?function=getRhymes&word=$cleanWord');
      debugPrint('🔍 Fetching rhymes for: $cleanWord');
      debugPrint('📡 API URL: $uri');

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response length: ${response.body.length}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('🎯 Raw data count: ${data.length}');
        
        final rhymes = data
            .map((item) => RhymeResult.fromJson(item as Map<String, dynamic>))
            .where((rhyme) => rhyme.word.isNotEmpty)
            .toList();
        
        debugPrint('✅ Parsed rhymes count: ${rhymes.length}');
        if (rhymes.isNotEmpty) {
          debugPrint('🎵 First few rhymes: ${rhymes.take(3).map((r) => '${r.word}(${r.score})').join(', ')}');
        }
        
        // Sort by score (higher is better) and take maxResults
        rhymes.sort((a, b) => b.score.compareTo(a.score));
        return rhymes.take(maxResults).toList();
      } else {
        debugPrint('❌ API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('💥 Exception in getRhymes: $e');
      return [];
    }

    return [];
  }

  Future<List<RhymeResult>> getNearRhymes(String word, {int maxResults = 15}) async {
    if (word.trim().isEmpty) return [];
    
    final cleanWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (cleanWord.isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/talk?function=getRhymes&word=$cleanWord');

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final rhymes = data
            .map((item) => RhymeResult.fromJson(item as Map<String, dynamic>))
            .where((rhyme) => rhyme.word.isNotEmpty)
            // Near rhymes typically have scores between 100-299
            .where((rhyme) => rhyme.score >= 100 && rhyme.score < 300)
            .toList();
        
        rhymes.sort((a, b) => b.score.compareTo(a.score));
        return rhymes.take(maxResults).toList();
      }
    } catch (e) {
      return [];
    }

    return [];
  }

  Future<List<RhymeResult>> findSlantRhymes(List<String> words) async {
    // For multiple words, we'll implement a placeholder approach
    // This could later be enhanced with more sophisticated slant rhyme detection
    if (words.isEmpty) return [];
    
    // For now, just return near rhymes for the first word as a starting point
    final firstWord = words.first;
    return await getNearRhymes(firstWord, maxResults: 10);
  }

  void dispose() {
    _client.close();
  }
}