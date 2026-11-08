import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../models/sync_operation.dart';
import 'storage_service.dart';

/// The outbox lives in each document's metadata, so browser document saves and
/// their pending operation commit in one transaction. Acknowledgements match an
/// operation ID, never just a document ID: edits during an upload stay pending.
class SyncQueueService {
  static final _migrationLock = Lock();
  static SyncOperation newOperation(String fileId, SyncOperationType type) =>
      SyncOperation(
          id: List.generate(
              16,
              (_) => Random.secure()
                  .nextInt(256)
                  .toRadixString(16)
                  .padLeft(2, '0')).join(),
          fileId: fileId,
          type: type,
          createdAt: DateTime.now().toUtc());

  Future<void> _migrateLegacy() => _migrationLock.synchronized(() async {
        final storage = StorageService.create();
        if (storage is IndexedDbStorageService) {
          return; // Migrated by its opening transaction.
        }
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('documentOutboxMigrated') == true) return;
        for (final raw in prefs.getStringList('sync_queue') ?? <String>[]) {
          final op = SyncOperation.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
          final meta = await storage.getMetadata(op.fileId);
          if (meta == null && op.type != SyncOperationType.delete) continue;
          if (meta?['pendingSync'] != null) continue;
          await storage
              .saveDocument(op.fileId, await storage.readContent(op.fileId), {
            if (meta != null) ...meta,
            'id': op.fileId,
            'name': meta?['name'] ?? op.fileId,
            'lastModified':
                meta?['lastModified'] ?? op.createdAt.toIso8601String(),
            'deleted': op.type == SyncOperationType.delete,
            'pendingSync': op.toJson(),
          });
        }
        await prefs.setBool('documentOutboxMigrated', true);
      });

  Future<List<SyncOperation>> getQueue() async {
    await _migrateLegacy();
    final storage = StorageService.create();
    final queue = <SyncOperation>[];
    for (final id in await storage.getAllFileIds()) {
      final raw = (await storage.getMetadata(id))?['pendingSync'];
      if (raw != null) {
        queue
            .add(SyncOperation.fromJson(Map<String, dynamic>.from(raw as Map)));
      }
    }
    return queue;
  }

  Future<void> enqueue(String fileId, SyncOperationType type,
      {Map<String, dynamic>? metadata}) async {
    await StorageService.create().updateMetadata(fileId, (meta) {
      meta['pendingSync'] = newOperation(fileId, type).toJson();
    });
  }

  Future<List<SyncOperation>> getRetryableOperations() async =>
      (await getQueue()).where((op) => op.shouldRetry()).toList();

  Future<void> markAttempted(String operationId, {String? errorMessage}) async {
    for (final op in await getQueue()) {
      if (op.id != operationId) continue;
      await StorageService.create().updateMetadata(op.fileId, (meta) {
        if ((meta['pendingSync'] as Map?)?['id'] == operationId) {
          meta['pendingSync'] = op
              .copyWith(
                  retryCount: op.retryCount + 1,
                  lastAttempt: DateTime.now().toUtc(),
                  errorMessage: errorMessage)
              .toJson();
        }
      });
    }
  }

  Future<void> dequeue(String operationId) async {
    for (final op in await getQueue()) {
      if (op.id != operationId) continue;
      await StorageService.create().updateMetadata(op.fileId, (meta) {
        if ((meta['pendingSync'] as Map?)?['id'] == operationId) {
          meta['pendingSync'] = null;
        }
      });
    }
  }

  Future<void> dequeueFile(String fileId) => StorageService.create()
      .updateMetadata(fileId, (meta) => meta['pendingSync'] = null);

  Future<void> clearQueue() async {
    for (final op in await getQueue()) {
      await dequeue(op.id);
    }
  }

  Future<void> resetRetries() async {
    for (final op in await getQueue()) {
      await StorageService.create().updateMetadata(op.fileId, (meta) {
        if ((meta['pendingSync'] as Map?)?['id'] == op.id) {
          meta['pendingSync'] = newOperation(op.fileId, op.type).toJson();
        }
      });
    }
  }

  Future<Map<String, dynamic>> getSyncStats() => getQueueStats();
  Future<Map<String, dynamic>> getQueueStats() async {
    final queue = await getQueue();
    final retryable = queue.where((op) => op.shouldRetry()).length;
    final failed = queue.where((op) => op.retryCount >= 10).length;
    return {
      'total': queue.length,
      'retryable': retryable,
      'failed': failed,
      'pending': queue.length - retryable - failed
    };
  }

  // Retain legacy diagnostic access without treating the log as the outbox.
  Future<List<SyncTransaction>> getTransactionLog({int? limit}) async {
    final prefs = await SharedPreferences.getInstance();
    final log = (prefs.getStringList('transaction_log') ?? <String>[])
        .map((raw) => SyncTransaction.fromJson(jsonDecode(raw)))
        .toList();
    log.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return limit == null ? log : log.take(limit).toList();
  }

  Future<List<SyncTransaction>> getFileTransactions(String id) async =>
      (await getTransactionLog()).where((entry) => entry.fileId == id).toList();
  Future<void> pruneTransactionLog() async {}
  Future<void> clearAll() async {
    await clearQueue();
    await (await SharedPreferences.getInstance()).remove('transaction_log');
  }
}
