import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('Debug CMU Dictionary Format', () async {
    const url = 'https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict';
    
    try {
      print('Fetching CMU dictionary from: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final lines = LineSplitter.split(response.body).take(20); // First 20 lines
        
        print('First 20 lines of CMU dictionary:');
        print('=' * 60);
        
        for (int i = 0; i < lines.length; i++) {
          final line = lines.elementAt(i);
          print('Line $i: "$line"');
          
          if (line.trim().isNotEmpty && !line.startsWith(';;;')) {
            // Test different separators
            print('  Split by "  " (double space): ${line.split('  ')}');
            print('  Split by " " (single space): ${line.split(' ')}');
            print('  Split by tab: ${line.split('\t')}');
            print('  Split by regex \\s+: ${line.split(RegExp(r'\s+'))}');
            print('');
          }
        }
        
        // Count total lines
        final totalLines = LineSplitter.split(response.body).length;
        print('Total lines in dictionary: $totalLines');
        
        // Count non-comment lines
        final dataLines = LineSplitter.split(response.body)
            .where((line) => line.trim().isNotEmpty && !line.startsWith(';;;'))
            .length;
        print('Data lines (non-comment): $dataLines');
        
      } else {
        print('Failed to fetch dictionary: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  });
}