import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WritingFile {
  final String id;
  final String name;
  DateTime lastModified;
  String? content;
  static const String fileExtension = '.text';

  WritingFile({
    required this.id,
    required this.name,
    DateTime? lastModified,
    this.content,
  }) : lastModified = lastModified ?? DateTime.now();

  Future<String> get _localPath async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/writing_files';
      // Ensure directory exists
      await Directory(path).create(recursive: true);
      debugPrint('Local path: $path');
      return path;
    } catch (e) {
      debugPrint('Error getting local path: $e');
      rethrow;
    }
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    // Use a more reliable file naming convention
    return File('$path/$id$fileExtension');
  }

  Future<void> writeContent(String newContent) async {
    try {
      final file = await _localFile;

      // Ensure directory exists
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Write content
      await file.writeAsString(
        newContent,
        mode: FileMode.write,
        flush: true,
      );

      // Update in-memory content
      content = newContent;
      lastModified = DateTime.now();

      // Save metadata
      await _saveMetadata();

      debugPrint('File written successfully to: ${file.path}');
      debugPrint('Content length: ${newContent.length}');
    } catch (e) {
      debugPrint('Error writing file: $e');
      rethrow;
    }
  }

  Future<String> readContent() async {
    try {
      final file = await _localFile;

      if (await file.exists()) {
        final fileContent = await file.readAsString();
        content = fileContent;
        debugPrint('File read successfully from: ${file.path}');
        debugPrint('Content length: ${fileContent.length}');
        return fileContent;
      }

      debugPrint('File does not exist at: ${file.path}');
      return content ?? '';
    } catch (e) {
      debugPrint('Error reading file: $e');
      return content ?? '';
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      await prefs.setString(
          key,
          json.encode({
            'id': id,
            'name': name,
            'lastModified': lastModified.toIso8601String(),
          }));
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }

  static Future<DateTime?> getLastModified(String fileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$fileId';
      final metadata = prefs.getString(key);
      if (metadata != null) {
        final data = json.decode(metadata);
        return DateTime.parse(data['lastModified']);
      }
    } catch (e) {
      debugPrint('Error getting metadata: $e');
    }
    return null;
  }

  Future<void> delete() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  // For JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
    };
  }

  // For creating WritingFile from JSON
  factory WritingFile.fromJson(Map<String, dynamic> json) {
    return WritingFile(
      id: json['id'],
      name: json['name'],
      content: json['content'],
    );
  }

  // For creating a copy of WritingFile with modifications
  WritingFile copyWith({
    String? id,
    String? name,
    String? content,
  }) {
    return WritingFile(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WritingFile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
