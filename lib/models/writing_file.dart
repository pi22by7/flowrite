// lib/models/writing_file.dart
import 'dart:io';
import 'package:path/path.dart' as p;  // Changed import alias to 'p'

class WritingFile {
  final String name;
  final String path;

  WritingFile({required this.name, required this.path});

  Future<String> readContent() async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> writeContent(String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  static WritingFile fromFile(File file) {
    return WritingFile(
      name: p.basenameWithoutExtension(file.path),  // Fixed method call using the 'p' alias
      path: file.path,
    );
  }
}
