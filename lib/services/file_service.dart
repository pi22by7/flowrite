// lib/services/file_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/writing_file.dart';

class FileService {
  Future<String> get _directoryPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/writings';
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<List<WritingFile>> getFiles() async {
    final path = await _directoryPath;
    final directory = Directory(path);

    if (!await directory.exists()) {
      return [];
    }

    return directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.txt'))
        .map((file) => WritingFile.fromFile(file))
        .toList();
  }

  Future<WritingFile> createFile(String name) async {
    final path = await _directoryPath;
    final file = File('$path/$name.txt');
    await file.create();
    return WritingFile.fromFile(file);
  }

  Future<void> deleteFile(WritingFile file) async {
    final fileToDelete = File(file.path);
    if (await fileToDelete.exists()) {
      await fileToDelete.delete();
    }
  }

  renameFile(WritingFile file, String name) {
    final oldFile = File(file.path);
    final newPath = file.path.replaceFirst(file.name, name);
    final newFile = File(newPath);
    oldFile.rename(newFile.path);
  }
}
