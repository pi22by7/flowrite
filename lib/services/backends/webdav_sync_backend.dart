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

/// One JSON record per document. Deleted documents remain as tombstones so
/// devices that were offline can learn about deletions when they reconnect.
class WebDavSyncBackend implements SyncBackend {
  static const _remoteDir = '/flowrite/';
  final WebDavConfigService _configService;
  final SyncQueueService _queueService = SyncQueueService();
  final ConflictResolutionService _conflicts = ConflictResolutionService();
  final Dio _http;
  final webdav.Client Function(WebDavConfig)? clientFactory;
  WebDavConfig? _config;
  Future<void>? _processing;
  final _statusController = StreamController<SyncStatus>.broadcast();

  WebDavSyncBackend(
      {WebDavConfigService? configService, Dio? http, this.clientFactory})
      : _configService = configService ?? WebDavConfigService(),
        _http = http ?? Dio();

  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;
  void _status(SyncStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<WebDavConfig?> _loadConfig() async {
    _config = await _configService.getConfig();
    return _config;
  }

  @override
  bool get isSignedIn => _config != null;

  webdav.Client _client(WebDavConfig config) {
    if (clientFactory != null) return clientFactory!(config);
    return webdav.newClient(config.serverUrl,
        user: config.username, password: config.appPassword)
      // Send credentials on the first browser request. An unauthenticated
      // challenge can become an XHR authentication error before Dart sees it.
      ..auth = webdav.BasicAuth(user: config.username, pwd: config.appPassword)
      ..setConnectTimeout(5000)
      ..setSendTimeout(15000)
      ..setReceiveTimeout(15000);
  }

  @override
  Future<bool> get isOnline async {
    final config = await _loadConfig();
    if (config == null) return false;
    try {
      await _client(config).ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Response<dynamic>> _request(
      WebDavConfig config, String fileId, String method,
      {String? data, Map<String, dynamic>? headers}) {
    final root = config.serverUrl.replaceAll(RegExp(r'/+$'), '');
    final url = '$root$_remoteDir${Uri.encodeComponent(fileId)}.json';
    return _http
        .request<dynamic>(url,
            data: data,
            options: Options(
              method: method,
              responseType: ResponseType.plain,
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Authorization':
                    'Basic ${base64Encode(utf8.encode('${config.username}:${config.appPassword}'))}',
                'Content-Type': 'application/json',
                'Cache-Control': 'no-cache',
                ...?headers
              },
              validateStatus: (status) =>
                  status != null &&
                  (status < 300 || status == 404 || status == 412),
            ))
        .timeout(const Duration(seconds: 20));
  }

  Future<({WritingFile? file, String? etag})> _readRemote(
      WebDavConfig config, String id) async {
    final response = await _request(config, id, 'GET');
    if (response.statusCode == 404) return (file: null, etag: null);
    final file = WritingFile.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.data as String) as Map));
    if (file.id != id) {
      throw FormatException('Remote document ID does not match its path');
    }
    return (file: file, etag: response.headers.value('etag'));
  }

  @override
  Future<bool> syncFile(WritingFile file) async {
    await _queueService.enqueue(file.id,
        file.isDeleted ? SyncOperationType.delete : SyncOperationType.update);
    await processSyncQueue();
    return !(await _queueService.getQueue()).any((op) => op.fileId == file.id);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    // All deletion paths use the same conflict-aware outbox as edits.
    final metadata = await StorageService.create().getMetadata(fileId);
    if (metadata?['deleted'] != true) {
      await WritingFile(id: fileId, name: metadata?['name'] ?? fileId).delete();
    }
    await processSyncQueue();
  }

  @override
  Stream<List<WritingFile>> getFilesStream() async* {
    final config = await _loadConfig();
    if (config == null) return;
    final client = _client(config);
    await client.mkdirAll(_remoteDir);
    for (final entry in await client.readDir(_remoteDir)) {
      if (entry.isDir == true || !(entry.name?.endsWith('.json') ?? false)) {
        continue;
      }
      final id = entry.name!.substring(0, entry.name!.length - 5);
      try {
        final remote = await _readRemote(config, id);
        if (remote.file != null) yield [remote.file!];
      } catch (e) {
        // An invalid record must not prevent other documents from downloading.
        debugPrint('Could not download WebDAV document $id: $e');
      }
    }
  }

  @override
  Future<void> queueFileSync(WritingFile file, SyncOperationType type) async {
    await _queueService.enqueue(file.id, type);
    await processSyncQueue();
  }

  @override
  Future<void> processSyncQueue() async {
    if (_processing != null) return _processing;
    _processing = _process();
    try {
      await _processing;
    } finally {
      _processing = null;
    }
  }

  Future<void> _process() async {
    final config = await _loadConfig();
    if (config == null) return;
    if (!await isOnline) {
      _status(SyncStatus.pending);
      return;
    }
    _status(SyncStatus.syncing);
    try {
      await _client(config).mkdirAll(_remoteDir);
      for (final operation in await _queueService.getRetryableOperations()) {
        try {
          await _syncOperation(config, operation);
          await _queueService.dequeue(operation.id);
        } catch (e) {
          await _queueService.markAttempted(operation.id,
              errorMessage: e.toString());
          debugPrint('WebDAV sync failed for ${operation.fileId}: $e');
        }
      }
      final remaining = await _queueService.getQueue();
      _status(remaining.isEmpty ? SyncStatus.synced : SyncStatus.pending);
    } catch (e) {
      _status(SyncStatus.error);
      debugPrint('WebDAV sync failed: $e');
    }
  }

  Future<void> _syncOperation(
      WebDavConfig config, SyncOperation operation) async {
    final storage = StorageService.create();
    final record = await storage.readDocument(operation.fileId);
    if (record == null) throw StateError('Local document is missing');
    final meta = Map<String, dynamic>.from(record['metadata'] as Map);
    if ((meta['pendingSync'] as Map?)?['id'] != operation.id) return;
    final local = WritingFile.fromJson(
        {...meta, 'id': operation.fileId, 'content': record['content']});
    final remote = await _readRemote(config, local.id);
    final other = remote.file;
    if (other != null &&
        other.snapshot != local.snapshot &&
        meta['remoteSnapshot'] != other.snapshot) {
      // With no common revision, preserve the losing text before selecting a
      // winner. Deletions win to prevent stale devices resurrecting documents.
      final remoteWins = other.isDeleted ||
          !local.isDeleted && other.lastModified.isAfter(local.lastModified);
      final loser = remoteWins ? local : other;
      if (!loser.isDeleted &&
          loser.content != (remoteWins ? other.content : local.content) &&
          (loser.content?.isNotEmpty ?? false)) {
        await _conflicts.createBackup(loser, 'conflict');
      }
      if (remoteWins) {
        await other.saveRemote(expectedOperationId: operation.id);
        return;
      }
    }
    if (other?.snapshot != local.snapshot) {
      // Refuse to overwrite a concurrent remote write. The unchanged operation
      // remains pending and is re-evaluated on the next attempt.
      if (other != null && remote.etag == null) {
        throw StateError(
            'The WebDAV server must supply ETags for safe updates');
      }
      final result = await _request(config, local.id, 'PUT',
          data: local.snapshot,
          headers: other == null
              ? {'If-None-Match': '*'}
              : {'If-Match': remote.etag!});
      if (result.statusCode == 412) {
        throw StateError('Document changed on server; retrying');
      }
      if (result.statusCode == 404) {
        throw StateError('Remote directory is missing');
      }
    }
    await storage.updateMetadata(local.id, (metadata) {
      metadata['remoteSnapshot'] = local.snapshot;
      // dequeue(operation.id) only acknowledges this exact version.
    });
  }

  @override
  Future<Map<String, dynamic>> getSyncStats() => _queueService.getQueueStats();
  @override
  Future<void> clearSyncData() async {
    _status(SyncStatus.idle);
  }

  @override
  void dispose() {
    _http.close();
    _statusController.close();
  }
}
