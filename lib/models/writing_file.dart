import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_queue_service.dart';
import '../models/sync_operation.dart';

class WritingFile {
  final String id;
  final String name;
  DateTime lastModified;
  String? content;
  late final StorageService _storage;
  late final SyncQueueService _syncQueue;

  WritingFile({
    required this.id,
    required this.name,
    DateTime? lastModified,
    this.content,
  }) : lastModified = lastModified ?? DateTime.now() {
    _storage = StorageService.create();
    _syncQueue = SyncQueueService();
  }

  Future<void> writeContent(String newContent) async {
    try {
      // Write to local storage first (local-first approach)
      await _storage.writeContent(id, newContent);

      // Update in-memory content
      content = newContent;
      lastModified = DateTime.now();

      // Save metadata
      await _saveMetadata();

      // Queue for sync (non-blocking)
      _queueSync(SyncOperationType.update);

      debugPrint('✅ Content written successfully for file $id');
      debugPrint('   Content length: ${newContent.length}');
    } catch (e) {
      debugPrint('❌ Error writing file: $e');
      rethrow;
    }
  }

  /// Queue file for cloud sync (non-blocking)
  void _queueSync(SyncOperationType type) {
    // Fire and forget - don't block on sync
    _syncQueue.enqueue(id, type, metadata: {
      'name': name,
      'lastModified': lastModified.toIso8601String(),
    }).catchError((error) {
      debugPrint('⚠️ Error queuing sync: $error');
      // Don't fail the write operation if queue fails
    });
  }

  Future<String> readContent() async {
    try {
      final fileContent = await _storage.readContent(id);
      content = fileContent;
      debugPrint('Content read successfully for file $id');
      debugPrint('Content length: ${fileContent.length}');
      return fileContent;
    } catch (e) {
      debugPrint('Error reading file: $e');
      return content ?? '';
    }
  }

  Future<void> _saveMetadata() async {
    try {
      await _storage.saveMetadata(id, {
        'id': id,
        'name': name,
        'lastModified': lastModified.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }

  static Future<DateTime?> getLastModified(String fileId) async {
    try {
      final storage = StorageService.create();
      final metadata = await storage.getMetadata(fileId);
      if (metadata != null) {
        return DateTime.parse(metadata['lastModified']);
      }
    } catch (e) {
      debugPrint('Error getting metadata: $e');
    }
    return null;
  }

  Future<void> delete() async {
    try {
      // Delete from local storage
      await _storage.deleteContent(id);

      // Queue for cloud deletion
      _queueSync(SyncOperationType.delete);

      debugPrint('✅ File deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
    }
  }

  // For JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  // For creating WritingFile from JSON
  factory WritingFile.fromJson(Map<String, dynamic> json) {
    return WritingFile(
      id: json['id'],
      name: json['name'],
      content: json['content'],
      lastModified: json['lastModified'] != null 
          ? DateTime.parse(json['lastModified'])
          : DateTime.now(),
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
