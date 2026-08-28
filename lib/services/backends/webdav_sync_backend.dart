import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../models/writing_file.dart';
import '../../models/sync_operation.dart';
import '../conflict_resolution_service.dart';
import '../storage_service.dart';
import '../sync_backend.dart';
import '../sync_queue_service.dart';
import '../webdav_config_service.dart';

/// WebDAV-backed [SyncBackend] for NextCloud/ownCloud/generic WebDAV servers.
/// Each file is stored as a single JSON blob at `/flowrite/<id>.json` under
/// the account root, authenticated with a server URL + username + app
/// password (no OAuth).
class WebDavSyncBackend implements SyncBackend {
  static const String _remoteDir = '/flowrite/';

  final WebDavConfigService _configService = WebDavConfigService();
  final SyncQueueService _queueService = SyncQueueService();
  final ConflictResolutionService _conflictService = ConflictResolutionService();

  WebDavConfig? _cachedConfig;
  bool _dirEnsured = false;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  final _statusController = StreamController<SyncStatus>.broadcast();
  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Re-reads credentials from secure storage. [isSignedIn] reflects
  /// whatever was cached by the most recent call to this (or [isOnline],
  /// which calls it first) - callers that check [isOnline] before
  /// [isSignedIn], as [FileService] does, always see a fresh value.
  Future<WebDavConfig?> _ensureConfigLoaded() async {
    _cachedConfig = await _configService.getConfig();
    return _cachedConfig;
  }

  @override
  bool get isSignedIn => _cachedConfig != null;

  webdav.Client _client(WebDavConfig config) {
    return webdav.newClient(
      config.serverUrl,
      user: config.username,
      password: config.appPassword,
    );
  }

  Future<void> _ensureRemoteDir(webdav.Client client) async {
    if (_dirEnsured) return;
    await client.mkdirAll(_remoteDir);
    _dirEnsured = true;
  }

  @override
  Future<bool> get isOnline async {
    final config = await _ensureConfigLoaded();
    if (config == null) return false;

    try {
      await _client(config).ping();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> syncFile(WritingFile file) async {
    final config = _cachedConfig ?? await _ensureConfigLoaded();
    if (config == null) {
      debugPrint('WebDAV not configured, cannot sync file ${file.id}');
      return false;
    }

    try {
      final client = _client(config);
      await _ensureRemoteDir(client);

      final content = await file.readContent();
      final payload = utf8.encode(json.encode({
        'id': file.id,
        'name': file.name,
        'content': content,
        'lastModified': file.lastModified.toIso8601String(),
      }));

      await client.write(
        '$_remoteDir${file.id}.json',
        Uint8List.fromList(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('✅ Synced file ${file.id} to WebDAV');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing file ${file.id} to WebDAV: $e');
      return false;
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final config = _cachedConfig ?? await _ensureConfigLoaded();
    if (config == null) return;

    try {
      final client = _client(config);
      await client.remove('$_remoteDir$fileId.json');
    } catch (e) {
      debugPrint('Error deleting file from WebDAV: $e');
      rethrow;
    }
  }

  Future<WritingFile?> _readRemoteFile(webdav.Client client, String fileId) async {
    try {
      final bytes = await client.read('$_remoteDir$fileId.json');
      final data = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      return WritingFile(
        id: data['id'],
        name: data['name'],
        content: data['content'],
        lastModified: DateTime.parse(data['lastModified']),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Stream<List<WritingFile>> getFilesStream() {
    return Stream.fromFuture(_fetchAllFiles());
  }

  Future<List<WritingFile>> _fetchAllFiles() async {
    final config = await _ensureConfigLoaded();
    if (config == null) return [];

    try {
      final client = _client(config);
      await _ensureRemoteDir(client);

      final entries = await client.readDir(_remoteDir);
      final files = <WritingFile>[];

      for (final entry in entries) {
        if (entry.isDir == true || entry.name == null || !entry.name!.endsWith('.json')) {
          continue;
        }
        final fileId = entry.name!.replaceAll('.json', '');
        final file = await _readRemoteFile(client, fileId);
        if (file != null) files.add(file);
      }

      return files;
    } catch (e) {
      debugPrint('Error listing WebDAV files: $e');
      return [];
    }
  }

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

  @override
  Future<void> processSyncQueue() async {
    final config = await _ensureConfigLoaded();
    if (config == null) {
      debugPrint('⚠️ WebDAV not configured, skipping sync');
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
            await _queueService.markAttempted(operation.id, errorMessage: 'Sync failed');
          }
        } catch (e) {
          failureCount++;
          await _queueService.markAttempted(operation.id, errorMessage: e.toString());
          debugPrint('❌ Error processing operation ${operation.id}: $e');
        }
      }

      debugPrint('📊 Sync complete: $successCount succeeded, $failureCount failed');

      if (failureCount == 0) {
        _updateStatus(SyncStatus.synced);
      } else if (successCount == 0) {
        _updateStatus(SyncStatus.error);
      } else {
        _updateStatus(SyncStatus.pending);
      }
    } catch (e) {
      debugPrint('❌ Error processing sync queue: $e');
      _updateStatus(SyncStatus.error);
    }
  }

  Future<bool> _processSingleOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        return await _syncFileWithConflictResolution(operation.fileId);
      case SyncOperationType.delete:
        try {
          await deleteFile(operation.fileId);
          return true;
        } catch (e) {
          return false;
        }
    }
  }

  Future<bool> _syncFileWithConflictResolution(String fileId) async {
    final config = _cachedConfig;
    if (config == null) return false;

    try {
      final storage = StorageService.create();
      final metadata = await storage.getMetadata(fileId);
      if (metadata == null) {
        debugPrint('⚠️ No metadata found for file $fileId');
        return false;
      }

      final localFile = WritingFile(
        id: fileId,
        name: metadata['name'] ?? '',
        lastModified: DateTime.parse(metadata['lastModified']),
      );
      await localFile.readContent();

      final client = _client(config);
      await _ensureRemoteDir(client);
      final remoteFile = await _readRemoteFile(client, fileId);

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

      final content = await localFile.readContent();
      final payload = utf8.encode(json.encode({
        'id': fileId,
        'name': metadata['name'],
        'content': content,
        'lastModified': metadata['lastModified'],
      }));

      await client.write('$_remoteDir$fileId.json', Uint8List.fromList(payload))
          .timeout(const Duration(seconds: 15));

      debugPrint('✅ Synced file $fileId to WebDAV');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing file to WebDAV: $e');
      return false;
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
