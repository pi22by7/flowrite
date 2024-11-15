// lib/models/writing_file.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class WritingFile {
  final String id;
  final String name;
  DateTime lastModified = DateTime.now();
  String? content;

  WritingFile({
    required this.id,
    required this.name,
    this.content,
  });

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/file_$id.txt');
  }

  Future<String> readContent() async {
    try {
      if (content != null) return content!;

      final file = await _localFile;

      // Read the file if it exists
      if (await file.exists()) {
        content = await file.readAsString();
        return content!;
      }

      // Return empty string if file doesn't exist
      content = '';
      return content!;
    } catch (e) {
      debugPrint('Error reading file: $e');
      return '';
    }
  }

  Future<void> writeContent(String newContent) async {
    try {
      content = newContent;
      final file = await _localFile;
      await file.writeAsString(newContent);
    } catch (e) {
      debugPrint('Error writing file: $e');
    }
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
