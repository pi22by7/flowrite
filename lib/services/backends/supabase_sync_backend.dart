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
  final ConflictResolutionService _conflictService =
      ConflictResolutionService();

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
    if (!_statusController.isClosed) _statusController.add(newStatus);
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
          .withConverter((data) => data)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> syncFile(WritingFile file) async {
    await queueFileSync(file,
        file.isDeleted ? SyncOperationType.delete : SyncOperationType.update);
    return !(await _queueService.getQueue()).any((op) => op.fileId == file.id);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final meta = await StorageService.create().getMetadata(fileId);
    if (meta?['deleted'] != true) {
      await WritingFile(id: fileId, name: meta?['name'] ?? fileId).delete();
    }
    await processSyncQueue();
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
                  isDeleted: item['deleted'] == true,
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
  Future<void>? _processing;
  @override
  Future<void> processSyncQueue() async {
    if (_processing != null) return _processing;
    _processing = _processSyncQueue();
    try {
      await _processing;
    } finally {
      _processing = null;
    }
  }

  Future<void> _processSyncQueue() async {
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

      debugPrint(
          '📊 Sync complete: $successCount succeeded, $failureCount failed');

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
    try {
      final storage = StorageService.create();
      final record = await storage.readDocument(operation.fileId);
      if (record == null) return false;
      final meta = Map<String, dynamic>.from(record['metadata'] as Map);
      if ((meta['pendingSync'] as Map?)?['id'] != operation.id) return true;
      final local = WritingFile.fromJson(
          {...meta, 'id': operation.fileId, 'content': record['content']});
      final remoteData = await _supabase
          .from('user_files')
          .select()
          .eq('id', operation.fileId)
          .eq('user_id', _userId)
          .maybeSingle();
      final remote =
          remoteData == null ? null : WritingFile.fromJson(remoteData);
      if (remote != null &&
          remote.snapshot != local.snapshot &&
          meta['remoteSnapshot'] != remote.snapshot) {
        final remoteWins = remote.isDeleted ||
            !local.isDeleted && remote.lastModified.isAfter(local.lastModified);
        final loser = remoteWins ? local : remote;
        if (!loser.isDeleted &&
            loser.content != (remoteWins ? remote.content : local.content) &&
            (loser.content?.isNotEmpty ?? false)) {
          await _conflictService.createBackup(loser, 'conflict');
        }
        if (remoteWins) {
          await remote.saveRemote(expectedOperationId: operation.id);
          return true;
        }
      }
      final payload = {
        'id': local.id,
        'user_id': _userId,
        'name': local.name,
        'content': local.content,
        'deleted': local.isDeleted,
        'last_modified': local.lastModified.toUtc().toIso8601String(),
      };
      if (remoteData == null) {
        await _supabase
            .from('user_files')
            .insert(payload)
            .timeout(const Duration(seconds: 15));
      } else if (remote!.snapshot != local.snapshot) {
        final updated = await _supabase
            .from('user_files')
            .update(payload)
            .eq('id', local.id)
            .eq('user_id', _userId)
            .eq('updated_at', remoteData['updated_at'])
            .select('id')
            .timeout(const Duration(seconds: 15));
        if (updated.isEmpty) return false;
      }
      await storage.updateMetadata(
          local.id, (metadata) => metadata['remoteSnapshot'] = local.snapshot);
      return true;
    } catch (e) {
      debugPrint('Supabase sync failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getSyncStats() async {
    return await _queueService.getQueueStats();
  }

  @override
  Future<void> clearSyncData() async {
    _updateStatus(SyncStatus.idle);
  }

  @override
  void dispose() {
    _statusController.close();
  }
}
