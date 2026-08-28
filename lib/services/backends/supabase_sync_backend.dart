import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/writing_file.dart';
import '../../models/sync_operation.dart';
import '../auth_service.dart';
import '../sync_queue_service.dart';
import '../conflict_resolution_service.dart';
import '../storage_service.dart';
import '../sync_backend.dart';

/// Supabase-backed [SyncBackend]. Consolidates what used to be two separate
/// classes (`CloudSyncService` for immediate upload/streaming, and
/// `ResilientSyncService` for the retry queue + conflict resolution) into
/// one implementation of the shared interface.
class SupabaseSyncBackend implements SyncBackend {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();
  final SyncQueueService _queueService = SyncQueueService();
  final ConflictResolutionService _conflictService = ConflictResolutionService();

  String get _userId => _supabase.auth.currentUser?.id ?? '';

  @override
  bool get isSignedIn => _userId.isNotEmpty;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  final _statusController = StreamController<SyncStatus>.broadcast();
  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<bool> _ensureValidSession() async {
    if (!isSignedIn) return false;

    try {
      final isValid = await _authService.isSessionValid();
      if (!isValid) {
        debugPrint('🔄 Session invalid, attempting to refresh...');
        final refreshed = await _authService.refreshSession();
        if (!refreshed) {
          debugPrint('❌ Failed to refresh session');
          return false;
        }
        debugPrint('✅ Session refreshed successfully');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error ensuring valid session: $e');
      return false;
    }
  }

  @override
  Future<bool> get isOnline async {
    try {
      if (!await _ensureValidSession()) return false;

      await _supabase
          .from('user_files')
          .select('id')
          .limit(1)
          .withConverter((data) => data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Immediate upload of one file, used right after a local save.
  @override
  Future<bool> syncFile(WritingFile file) async {
    if (_userId.isEmpty) {
      debugPrint('User not signed in, cannot sync file ${file.id}');
      return false;
    }

    try {
      if (!await _ensureValidSession()) {
        debugPrint('Invalid session, cannot sync file ${file.id}');
        return false;
      }

      if (!await isOnline) {
        debugPrint('Device is offline, cannot sync file ${file.id}');
        return false;
      }

      String content;
      try {
        content = await file.readContent();
      } catch (e) {
        debugPrint('Error reading content for file ${file.id}: $e');
        return false;
      }

      await _supabase.from('user_files').upsert({
        'id': file.id,
        'user_id': _userId,
        'name': file.name,
        'content': content,
        'last_modified': file.lastModified.toIso8601String(),
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Supabase upsert timeout'),
      );

      debugPrint('Successfully synced file ${file.id} to cloud');
      return true;
    } catch (e) {
      debugPrint('Error syncing file ${file.id} to cloud: $e');
      return false;
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (_userId.isEmpty) return;

    try {
      await _supabase
          .from('user_files')
          .delete()
          .eq('id', fileId)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('Error deleting file: $e');
      rethrow;
    }
  }

  @override
  Stream<List<WritingFile>> getFilesStream() {
    if (_userId.isEmpty) return Stream.value([]);

    return _supabase
        .from('user_files')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('last_modified', ascending: false)
        .handleError((error) {
          debugPrint('Stream error, attempting session refresh: $error');
          _ensureValidSession();
        })
        .map((data) => data
            .map((item) => WritingFile(
                  id: item['id'],
                  name: item['name'],
                  content: item['content'],
                  lastModified: DateTime.parse(item['last_modified']),
                ))
            .toList());
  }

  /// Queue a file for syncing (add to persistent queue)
  @override
  Future<void> queueFileSync(WritingFile file, SyncOperationType type) async {
    try {
      await _queueService.enqueue(
        file.id,
        type,
        metadata: {
          'name': file.name,
          'lastModified': file.lastModified.toIso8601String(),
        },
      );

      debugPrint('📝 Queued ${type.name} operation for file ${file.id}');

      if (await isOnline) {
        await processSyncQueue();
      } else {
        _updateStatus(SyncStatus.pending);
      }
    } catch (e) {
      debugPrint('❌ Error queuing file sync: $e');
      _updateStatus(SyncStatus.error);
    }
  }

  /// Process sync queue with exponential backoff retry
  @override
  Future<void> processSyncQueue() async {
    if (_userId.isEmpty) {
      debugPrint('⚠️ User not signed in, skipping sync');
      return;
    }

    if (!await isOnline) {
      debugPrint('⚠️ Device is offline, skipping sync');
      _updateStatus(SyncStatus.pending);
      return;
    }

    try {
      _updateStatus(SyncStatus.syncing);

      final retryableOps = await _queueService.getRetryableOperations();

      if (retryableOps.isEmpty) {
        debugPrint('✅ No operations to sync');
        _updateStatus(SyncStatus.synced);
        return;
      }

      debugPrint('🔄 Processing ${retryableOps.length} sync operations');

      int successCount = 0;
      int failureCount = 0;

      for (final operation in retryableOps) {
        try {
          final success = await _processSingleOperation(operation);
          if (success) {
            successCount++;
            await _queueService.dequeue(operation.id);
          } else {
            failureCount++;
            await _queueService.markAttempted(
              operation.id,
              errorMessage: 'Sync failed',
            );
          }
        } catch (e) {
          failureCount++;
          await _queueService.markAttempted(
            operation.id,
            errorMessage: e.toString(),
          );
          debugPrint('❌ Error processing operation ${operation.id}: $e');
        }
      }

      debugPrint('📊 Sync complete: $successCount succeeded, $failureCount failed');

      if (failureCount == 0) {
        _updateStatus(SyncStatus.synced);
      } else if (successCount == 0) {
        _updateStatus(SyncStatus.error);
      } else {
        _updateStatus(SyncStatus.pending); // Partial success
      }
    } catch (e) {
      debugPrint('❌ Error processing sync queue: $e');
      _updateStatus(SyncStatus.error);
    }
  }

  Future<bool> _processSingleOperation(SyncOperation operation) async {
    debugPrint('⚙️ Processing ${operation.type.name} for file ${operation.fileId}');

    try {
      switch (operation.type) {
        case SyncOperationType.create:
        case SyncOperationType.update:
          return await _syncFileToCloud(operation.fileId);

        case SyncOperationType.delete:
          return await _deleteFileFromCloud(operation.fileId);
      }
    } catch (e) {
      debugPrint('❌ Operation failed: $e');
      return false;
    }
  }

  /// Sync a file to cloud with conflict resolution
  Future<bool> _syncFileToCloud(String fileId) async {
    try {
      final localFile = WritingFile(id: fileId, name: '');
      final content = await localFile.readContent();
      final metadata = await _getLocalFileMetadata(fileId);

      if (metadata == null) {
        debugPrint('⚠️ No metadata found for file $fileId');
        return false;
      }

      final remoteData = await _supabase
          .from('user_files')
          .select()
          .eq('id', fileId)
          .eq('user_id', _userId)
          .maybeSingle();

      WritingFile? remoteFile;
      if (remoteData != null) {
        remoteFile = WritingFile.fromJson(remoteData);
      }

      if (remoteFile != null) {
        final hasConflict = _conflictService.hasConflict(localFile, remoteFile);

        if (hasConflict) {
          debugPrint('⚠️ Conflict detected for file $fileId');

          await _conflictService.createBackup(remoteFile, 'remote');

          final resolved = await _conflictService.resolveConflict(
            localFile: localFile,
            remoteFile: remoteFile,
            strategy: ConflictResolution.newerWins,
          );

          if (resolved.id == remoteFile.id) {
            await localFile.writeContent(remoteFile.content ?? '');
            debugPrint('✅ Conflict resolved: remote version kept');
            return true;
          }
        }
      }

      await _supabase.from('user_files').upsert({
        'id': fileId,
        'user_id': _userId,
        'name': metadata['name'],
        'content': content,
        'last_modified': metadata['lastModified'],
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Upload timeout'),
      );

      debugPrint('✅ Synced file $fileId to cloud');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing file to cloud: $e');
      return false;
    }
  }

  Future<bool> _deleteFileFromCloud(String fileId) async {
    try {
      await _supabase
          .from('user_files')
          .delete()
          .eq('id', fileId)
          .eq('user_id', _userId)
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Delete timeout'),
      );

      debugPrint('✅ Deleted file $fileId from cloud');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting file from cloud: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getLocalFileMetadata(String fileId) async {
    try {
      final storage = StorageService.create();
      return await storage.getMetadata(fileId);
    } catch (e) {
      debugPrint('❌ Error getting local metadata: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> getSyncStats() async {
    return await _queueService.getQueueStats();
  }

  @override
  Future<void> clearSyncData() async {
    await _queueService.clearAll();
    _updateStatus(SyncStatus.idle);
  }

  @override
  void dispose() {
    _statusController.close();
  }
}
