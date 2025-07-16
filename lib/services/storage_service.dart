import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StorageService {
  Future<void> writeContent(String id, String content);
  Future<String> readContent(String id);
  Future<void> deleteContent(String id);
  Future<List<String>> getAllFileIds();
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata);
  Future<Map<String, dynamic>?> getMetadata(String id);

  static StorageService create() {
    if (kIsWeb) {
      debugPrint('Creating WebStorageService for web platform');
      return WebStorageService();
    } else {
      debugPrint('Creating FileSystemStorageService for mobile platform');
      return FileSystemStorageService();
    }
  }
}

class FileSystemStorageService extends StorageService {
  static const String fileExtension = '.text';

  Future<String> get _localPath async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/writing_files';
      await Directory(path).create(recursive: true);
      debugPrint('Local path: $path');
      return path;
    } catch (e) {
      debugPrint('Error getting local path: $e');
      rethrow;
    }
  }

  Future<File> _getFile(String id) async {
    final path = await _localPath;
    return File('$path/$id$fileExtension');
  }

  @override
  Future<void> writeContent(String id, String content) async {
    try {
      final file = await _getFile(id);
      
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await file.writeAsString(
        content,
        mode: FileMode.write,
        flush: true,
      );

      debugPrint('File written successfully to: ${file.path}');
      debugPrint('Content length: ${content.length}');
    } catch (e) {
      debugPrint('Error writing file: $e');
      rethrow;
    }
  }

  @override
  Future<String> readContent(String id) async {
    try {
      final file = await _getFile(id);

      if (await file.exists()) {
        final fileContent = await file.readAsString();
        debugPrint('File read successfully from: ${file.path}');
        debugPrint('Content length: ${fileContent.length}');
        return fileContent;
      }

      debugPrint('File does not exist at: ${file.path}');
      return '';
    } catch (e) {
      debugPrint('Error reading file: $e');
      return '';
    }
  }

  @override
  Future<void> deleteContent(String id) async {
    try {
      final file = await _getFile(id);
      if (await file.exists()) {
        await file.delete();
        debugPrint('File deleted: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  @override
  Future<List<String>> getAllFileIds() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final writingFilesDir = Directory('${directory.path}/writing_files');

      if (!await writingFilesDir.exists()) {
        debugPrint('Writing files directory does not exist');
        return [];
      }

      final files = await writingFilesDir.list().toList();
      
      return files
          .where((file) => file.path.endsWith(fileExtension))
          .map((file) {
            final fileName = file.path.split('/').last;
            return fileName.replaceAll(fileExtension, '');
          })
          .toList();
    } catch (e) {
      debugPrint('Error getting file IDs: $e');
      return [];
    }
  }

  @override
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      await prefs.setString(key, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getMetadata(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      final metadata = prefs.getString(key);
      if (metadata != null) {
        return json.decode(metadata);
      }
    } catch (e) {
      debugPrint('Error getting metadata: $e');
    }
    return null;
  }
}

class WebStorageService extends StorageService {
  @override
  Future<void> writeContent(String id, String content) async {
    try {
      debugPrint('Web: Attempting to write content for file $id, length: ${content.length}');
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_content_$id';
      final success = await prefs.setString(key, content);
      debugPrint('Web: Content save result for file $id: $success');
      
      // Verify the write worked
      final savedContent = prefs.getString(key);
      debugPrint('Web: Verification - saved content length: ${savedContent?.length ?? 0}');
    } catch (e) {
      debugPrint('Error writing web content: $e');
      rethrow;
    }
  }

  @override
  Future<String> readContent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_content_$id';
      final content = prefs.getString(key) ?? '';
      debugPrint('Web: Content read for file $id, length: ${content.length}');
      return content;
    } catch (e) {
      debugPrint('Error reading web content: $e');
      return '';
    }
  }

  @override
  Future<void> deleteContent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contentKey = 'file_content_$id';
      final metadataKey = 'file_metadata_$id';
      
      await prefs.remove(contentKey);
      await prefs.remove(metadataKey);
      debugPrint('Web: Content and metadata deleted for file $id');
    } catch (e) {
      debugPrint('Error deleting web content: $e');
    }
  }

  @override
  Future<List<String>> getAllFileIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final fileIds = keys
          .where((key) => key.startsWith('file_content_'))
          .map((key) => key.replaceFirst('file_content_', ''))
          .toList();
      
      debugPrint('Web: Found ${fileIds.length} file IDs');
      return fileIds;
    } catch (e) {
      debugPrint('Error getting web file IDs: $e');
      return [];
    }
  }

  @override
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      await prefs.setString(key, json.encode(metadata));
      debugPrint('Web: Metadata saved for file $id');
    } catch (e) {
      debugPrint('Error saving web metadata: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getMetadata(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      final metadata = prefs.getString(key);
      if (metadata != null) {
        return json.decode(metadata);
      }
    } catch (e) {
      debugPrint('Error getting web metadata: $e');
    }
    return null;
  }
}