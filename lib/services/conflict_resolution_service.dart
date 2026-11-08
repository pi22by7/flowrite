import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/writing_file.dart';
import '../models/sync_operation.dart';
import 'storage_service.dart';

/// Service for resolving conflicts between local and remote versions
class ConflictResolutionService {
  /// Resolve conflict between local and remote file
  /// Returns the resolved file
  Future<WritingFile> resolveConflict({
    required WritingFile localFile,
    required WritingFile remoteFile,
    ConflictResolution strategy = ConflictResolution.newerWins,
  }) async {
    debugPrint('🔄 Resolving conflict for file ${localFile.id}');
    debugPrint('   Local modified: ${localFile.lastModified}');
    debugPrint('   Remote modified: ${remoteFile.lastModified}');
    debugPrint('   Strategy: ${strategy.name}');

    switch (strategy) {
      case ConflictResolution.localWins:
        debugPrint('✅ Local version wins');
        return localFile;

      case ConflictResolution.remoteWins:
        debugPrint('✅ Remote version wins');
        return remoteFile;

      case ConflictResolution.newerWins:
        // Compare timestamps and keep newer version
        if (localFile.lastModified.isAfter(remoteFile.lastModified)) {
          debugPrint('✅ Local version is newer');
          return localFile;
        } else if (remoteFile.lastModified.isAfter(localFile.lastModified)) {
          debugPrint('✅ Remote version is newer');
          return remoteFile;
        } else {
          // Same timestamp, prefer local
          debugPrint('⚠️ Same timestamp, preferring local');
          return localFile;
        }

      case ConflictResolution.manual:
        // For now, default to newerWins
        // In the future, this could trigger a UI dialog
        debugPrint('⚠️ Manual resolution not implemented, using newerWins');
        return resolveConflict(
          localFile: localFile,
          remoteFile: remoteFile,
          strategy: ConflictResolution.newerWins,
        );
    }
  }

  /// Check if two files have a conflict
  bool hasConflict(WritingFile localFile, WritingFile remoteFile) {
    // Files conflict if they have different content but similar timestamps
    // (within 5 seconds - could indicate concurrent edits)
    if (localFile.content == remoteFile.content) {
      return false; // Same content, no conflict
    }

    final timeDiff = localFile.lastModified
        .difference(remoteFile.lastModified)
        .abs()
        .inSeconds;

    // If modified within 5 seconds of each other with different content
    return timeDiff <= 5;
  }

  /// Create a conflict resolution report
  Map<String, dynamic> createConflictReport({
    required WritingFile localFile,
    required WritingFile remoteFile,
  }) {
    return {
      'fileId': localFile.id,
      'fileName': localFile.name,
      'hasConflict': hasConflict(localFile, remoteFile),
      'localModified': localFile.lastModified.toIso8601String(),
      'remoteModified': remoteFile.lastModified.toIso8601String(),
      'localContentLength': localFile.content?.length ?? 0,
      'remoteContentLength': remoteFile.content?.length ?? 0,
      'timeDifferenceSeconds':
          localFile.lastModified.difference(remoteFile.lastModified).inSeconds,
    };
  }

  /// Merge two versions (simple line-based merge)
  /// This is a basic implementation - could be enhanced with proper diff/merge
  WritingFile mergeVersions({
    required WritingFile localFile,
    required WritingFile remoteFile,
  }) {
    debugPrint('🔀 Attempting to merge versions for file ${localFile.id}');

    final localContent = localFile.content ?? '';
    final remoteContent = remoteFile.content ?? '';

    // If one is empty, use the other
    if (localContent.trim().isEmpty) {
      debugPrint('✅ Local is empty, using remote');
      return remoteFile;
    }
    if (remoteContent.trim().isEmpty) {
      debugPrint('✅ Remote is empty, using local');
      return localFile;
    }

    // For text files (poems/lyrics), prefer the longer version
    // as it's likely the user added content rather than removed it
    if (localContent.length > remoteContent.length) {
      debugPrint('✅ Local is longer, using local');
      return localFile;
    } else if (remoteContent.length > localContent.length) {
      debugPrint('✅ Remote is longer, using remote');
      return remoteFile;
    }

    // Same length but different content - use newer
    if (localFile.lastModified.isAfter(remoteFile.lastModified)) {
      debugPrint('✅ Same length, local is newer');
      return localFile;
    } else {
      debugPrint('✅ Same length, remote is newer');
      return remoteFile;
    }
  }

  /// Create a backup copy before resolving conflict
  Future<void> createBackup(WritingFile file, String suffix) async {
    try {
      final id =
          '${file.id}_backup_${sha256.convert(utf8.encode(file.snapshot))}';
      if (await StorageService.create().getMetadata(id) != null) return;
      final backupFile = WritingFile(
        id: id,
        name: '${file.name} (Backup $suffix)',
        content: file.content,
        lastModified: DateTime.now(),
      );

      await backupFile.writeContent(file.content ?? '');
      debugPrint('💾 Created backup: ${backupFile.id}');
    } catch (e) {
      debugPrint('❌ Error creating backup: $e');
      rethrow;
    }
  }
}
