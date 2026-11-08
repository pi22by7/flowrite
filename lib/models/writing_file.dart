import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_queue_service.dart';
import '../models/sync_operation.dart';

class WritingFile {
  final String id;
  String name;
  bool isDeleted;
  DateTime lastModified;
  String? content;
  late final StorageService _storage;

  WritingFile({
    required this.id,
    required this.name,
    this.isDeleted = false,
    DateTime? lastModified,
    this.content,
  }) : lastModified = lastModified ?? DateTime.now() {
    _storage = StorageService.create();
  }

  /// A successful local save includes the retry operation, before any network I/O.
  Future<void> writeContent(String newContent) async {
    content = newContent;
    lastModified = DateTime.now().toUtc();
    await _storage.saveDocument(id, newContent, {
      ...(toJson()..remove('content')),
      'pendingSync':
          SyncQueueService.newOperation(id, SyncOperationType.update).toJson(),
    });
  }

  /// Apply a downloaded version without changing its timestamp or re-uploading it.
  Future<bool> saveRemote(
      {String? remoteSnapshot, String? expectedOperationId}) async {
    return _storage.applyRemote(
        id,
        content ?? '',
        {
          ...(toJson()..remove('content')),
          'pendingSync': null,
          'remoteSnapshot': remoteSnapshot ?? snapshot,
        },
        expectedOperationId: expectedOperationId);
  }

  String get snapshot => jsonEncode(toJson());

  Future<String> readContent() async {
    content = await _storage.readContent(id);
    return content!;
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
    lastModified = DateTime.now().toUtc();
    isDeleted = true;
    content = '';
    await _storage.saveDocument(id, '', {
      ...(toJson()..remove('content')),
      'pendingSync':
          SyncQueueService.newOperation(id, SyncOperationType.delete).toJson(),
    });
  }

  // For JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'lastModified': lastModified.toUtc().toIso8601String(),
      'deleted': isDeleted,
    };
  }

  // For creating WritingFile from JSON
  factory WritingFile.fromJson(Map<String, dynamic> json) {
    return WritingFile(
      id: json['id'],
      name: json['name'],
      isDeleted: json['deleted'] == true,
      content: json['content'],
      lastModified: (json['lastModified'] ?? json['last_modified']) != null
          ? DateTime.parse(json['lastModified'] ?? json['last_modified'])
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
      isDeleted: isDeleted,
      lastModified: lastModified,
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
