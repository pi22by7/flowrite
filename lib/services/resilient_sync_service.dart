import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/writing_file.dart';
import '../models/sync_operation.dart';
import 'auth_service.dart';
import 'sync_queue_service.dart';
import 'conflict_resolution_service.dart';
import 'storage_service.dart';

/// Enhanced sync service with resilience features
class ResilientSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();
  final SyncQueueService _queueService = SyncQueueService();
  final ConflictResolutionService _conflictService = ConflictResolutionService();

  String get _userId => _supabase.auth.currentUser?.id ?? '';
  bool get isSignedIn => _userId.isNotEmpty;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  final _statusController = StreamController<SyncStatus>.broadcast();
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

  /// Queue a file for syncing (add to persistent queue)
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

      // Try immediate sync if online
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

  /// Process a single sync operation
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
      // Load local file
      final localFile = WritingFile(id: fileId, name: '');
      final content = await localFile.readContent();
      final metadata = await _getLocalFileMetadata(fileId);

      if (metadata == null) {
        debugPrint('⚠️ No metadata found for file $fileId');
        return false;
      }

      // Check for remote version
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

      // Resolve conflicts if remote version exists
      if (remoteFile != null) {
        final hasConflict = _conflictService.hasConflict(localFile, remoteFile);

        if (hasConflict) {
          debugPrint('⚠️ Conflict detected for file $fileId');

          // Create backup of remote version
          await _conflictService.createBackup(remoteFile, 'remote');

          // Resolve using newerWins strategy
          final resolved = await _conflictService.resolveConflict(
            localFile: localFile,
            remoteFile: remoteFile,
            strategy: ConflictResolution.newerWins,
          );

          // Use resolved version
          if (resolved.id == remoteFile.id) {
            // Remote won, update local
            await localFile.writeContent(remoteFile.content ?? '');
            debugPrint('✅ Conflict resolved: remote version kept');
            return true;
          }
        }
      }

      // Upsert to cloud
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

  /// Delete a file from cloud
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

  /// Get sync queue statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    return await _queueService.getQueueStats();
  }

  /// Clear all sync data
  Future<void> clearSyncData() async {
    await _queueService.clearAll();
    _updateStatus(SyncStatus.idle);
  }

  void dispose() {
    _statusController.close();
  }
}
