import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a [FileSystemStorageService.migrateStorageLocation] call.
class MigrationResult {
  final int migratedCount;
  final List<String> failedIds;

  MigrationResult({required this.migratedCount, required this.failedIds});

  bool get success => failedIds.isEmpty;
}

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
  static const String _customSavePathKey = 'customSavePath';

  Future<String> get _defaultPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/writing_files';
  }

  Future<String> get _localPath async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString(_customSavePathKey);
      final path = (customPath != null && customPath.isNotEmpty)
          ? customPath
          : await _defaultPath;
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

  /// Copies every file (content + metadata) from the current save location
  /// to [newBasePath], verifies each copy, then deletes the originals.
  /// Never deletes before a successful, verified copy.
  Future<MigrationResult> migrateStorageLocation(String newBasePath) async {
    final oldPath = await _localPath;
    if (oldPath == newBasePath) {
      return MigrationResult(migratedCount: 0, failedIds: []);
    }

    await Directory(newBasePath).create(recursive: true);

    final oldDir = Directory(oldPath);
    final failedIds = <String>[];
    var migratedCount = 0;

    if (await oldDir.exists()) {
      final files = await oldDir
          .list()
          .where((f) => f.path.endsWith(fileExtension))
          .toList();

      for (final entity in files) {
        final fileName = entity.path.split('/').last;
        final id = fileName.replaceAll(fileExtension, '');
        try {
          final oldFile = File(entity.path);
          final content = await oldFile.readAsString();

          final newFile = File('$newBasePath/$fileName');
          await newFile.writeAsString(content, mode: FileMode.write, flush: true);

          final verifiedContent = await newFile.readAsString();
          if (verifiedContent != content) {
            failedIds.add(id);
            continue;
          }

          migratedCount++;
        } catch (e) {
          debugPrint('Error migrating file $id: $e');
          failedIds.add(id);
        }
      }
    }

    if (failedIds.isNotEmpty) {
      debugPrint('Migration had ${failedIds.length} failures, aborting cleanup of old files');
      return MigrationResult(migratedCount: migratedCount, failedIds: failedIds);
    }

    // All files verified copied — safe to persist the new path and clean up old ones.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customSavePathKey, newBasePath);

    if (await oldDir.exists()) {
      final files = await oldDir
          .list()
          .where((f) => f.path.endsWith(fileExtension))
          .toList();
      for (final entity in files) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Error deleting old file ${entity.path}: $e');
        }
      }
    }

    return MigrationResult(migratedCount: migratedCount, failedIds: failedIds);
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
      final path = await _localPath;
      final writingFilesDir = Directory(path);

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