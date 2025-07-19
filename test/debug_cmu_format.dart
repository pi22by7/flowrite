import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('Debug CMU Dictionary Format', () async {
    const url =
        'https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict';

    try {
      debugPrint('Fetching CMU dictionary from: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final lines =
            LineSplitter.split(response.body).take(20); // First 20 lines

        debugPrint('First 20 lines of CMU dictionary:');
        debugPrint('=' * 60);

        for (int i = 0; i < lines.length; i++) {
          final line = lines.elementAt(i);
          debugPrint('Line $i: "$line"');

          if (line.trim().isNotEmpty && !line.startsWith(';;;')) {
            // Test different separators
            debugPrint('  Split by "  " (double space): ${line.split('  ')}');
            debugPrint('  Split by " " (single space): ${line.split(' ')}');
            debugPrint('  Split by tab: ${line.split('\t')}');
            debugPrint('  Split by regex \\s+: ${line.split(RegExp(r'\s+'))}');
            debugPrint('');
          }
        }

        // Count total lines
        final totalLines = LineSplitter.split(response.body).length;
        debugPrint('Total lines in dictionary: $totalLines');

        // Count non-comment lines
        final dataLines = LineSplitter.split(response.body)
            .where((line) => line.trim().isNotEmpty && !line.startsWith(';;;'))
            .length;
        debugPrint('Data lines (non-comment): $dataLines');
      } else {
        debugPrint('Failed to fetch dictionary: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  });
}
