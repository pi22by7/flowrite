import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_operation.dart';

/// Service for managing persistent sync queue and transaction log
class SyncQueueService {
  static const String _queueKey = 'sync_queue';
  static const String _transactionLogKey = 'transaction_log';
  static const int _maxTransactionLogSize = 1000; // Keep last 1000 transactions

  /// Generate a simple UUID-like ID
  String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '$timestamp-$randomPart';
  }

  /// Add operation to sync queue
  Future<void> enqueue(String fileId, SyncOperationType type, {Map<String, dynamic>? metadata}) async {
    try {
      // Create sync operation
      final operation = SyncOperation(
        id: _generateId(),
        fileId: fileId,
        type: type,
        createdAt: DateTime.now(),
      );

      // Create transaction log entry
      final transaction = SyncTransaction(
        id: _generateId(),
        fileId: fileId,
        operation: type,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      // Add to queue
      final queue = await _getQueue();

      // Remove any existing operations for this file (newer operation supersedes)
      queue.removeWhere((op) => op.fileId == fileId);
      queue.add(operation);

      await _saveQueue(queue);

      // Add to transaction log
      await _addTransaction(transaction);

      debugPrint('📝 Enqueued ${type.name} operation for file $fileId');
    } catch (e) {
      debugPrint('❌ Error enqueueing operation: $e');
      rethrow;
    }
  }

  /// Get all operations in queue
  Future<List<SyncOperation>> getQueue() async {
    return await _getQueue();
  }

  /// Get operations ready for retry
  Future<List<SyncOperation>> getRetryableOperations() async {
    final queue = await _getQueue();
    return queue.where((op) => op.shouldRetry()).toList();
  }

  /// Mark operation as attempted (increments retry count)
  Future<void> markAttempted(String operationId, {String? errorMessage}) async {
    try {
      final queue = await _getQueue();
      final index = queue.indexWhere((op) => op.id == operationId);

      if (index != -1) {
        queue[index] = queue[index].copyWith(
          retryCount: queue[index].retryCount + 1,
          lastAttempt: DateTime.now(),
          errorMessage: errorMessage,
        );
        await _saveQueue(queue);

        debugPrint('⏱️ Marked operation $operationId as attempted (retry ${queue[index].retryCount})');
      }
    } catch (e) {
      debugPrint('❌ Error marking operation as attempted: $e');
    }
  }

  /// Remove operation from queue (successful sync)
  Future<void> dequeue(String operationId) async {
    try {
      final queue = await _getQueue();
      queue.removeWhere((op) => op.id == operationId);
      await _saveQueue(queue);

      debugPrint('✅ Dequeued operation $operationId');
    } catch (e) {
      debugPrint('❌ Error dequeuing operation: $e');
    }
  }

  /// Remove all operations for a specific file
  Future<void> dequeueFile(String fileId) async {
    try {
      final queue = await _getQueue();
      queue.removeWhere((op) => op.fileId == fileId);
      await _saveQueue(queue);

      debugPrint('✅ Dequeued all operations for file $fileId');
    } catch (e) {
      debugPrint('❌ Error dequeuing file operations: $e');
    }
  }

  /// Clear entire queue
  Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      debugPrint('🗑️ Cleared sync queue');
    } catch (e) {
      debugPrint('❌ Error clearing queue: $e');
    }
  }

  /// Get transaction log
  Future<List<SyncTransaction>> getTransactionLog({int? limit}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getStringList(_transactionLogKey) ?? [];

      final transactions = logJson
          .map((json) => SyncTransaction.fromJson(jsonDecode(json)))
          .toList();

      // Sort by timestamp descending (newest first)
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (limit != null && limit > 0) {
        return transactions.take(limit).toList();
      }

      return transactions;
    } catch (e) {
      debugPrint('❌ Error getting transaction log: $e');
      return [];
    }
  }

  /// Get transactions for a specific file
  Future<List<SyncTransaction>> getFileTransactions(String fileId) async {
    final log = await getTransactionLog();
    return log.where((t) => t.fileId == fileId).toList();
  }

  /// Clear old transactions (keep only recent ones)
  Future<void> pruneTransactionLog() async {
    try {
      final transactions = await getTransactionLog();

      if (transactions.length > _maxTransactionLogSize) {
        // Keep only the most recent transactions
        final recentTransactions = transactions.take(_maxTransactionLogSize).toList();
        await _saveTransactionLog(recentTransactions);

        debugPrint('🧹 Pruned transaction log to ${recentTransactions.length} entries');
      }
    } catch (e) {
      debugPrint('❌ Error pruning transaction log: $e');
    }
  }

  /// Get queue statistics
  Future<Map<String, dynamic>> getQueueStats() async {
    final queue = await _getQueue();
    final retryable = queue.where((op) => op.shouldRetry()).length;
    final failed = queue.where((op) => op.retryCount >= 10).length;

    return {
      'total': queue.length,
      'retryable': retryable,
      'failed': failed,
      'pending': queue.length - retryable - failed,
    };
  }

  // Private helper methods

  Future<List<SyncOperation>> _getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getStringList(_queueKey) ?? [];

      return queueJson
          .map((json) => SyncOperation.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error reading queue: $e');
      return [];
    }
  }

  Future<void> _saveQueue(List<SyncOperation> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = queue.map((op) => jsonEncode(op.toJson())).toList();
      await prefs.setStringList(_queueKey, queueJson);
    } catch (e) {
      debugPrint('❌ Error saving queue: $e');
      rethrow;
    }
  }

  Future<void> _addTransaction(SyncTransaction transaction) async {
    try {
      final transactions = await getTransactionLog();
      transactions.insert(0, transaction); // Add to beginning

      // Keep only recent transactions
      if (transactions.length > _maxTransactionLogSize) {
        transactions.removeRange(_maxTransactionLogSize, transactions.length);
      }

      await _saveTransactionLog(transactions);
    } catch (e) {
      debugPrint('❌ Error adding transaction: $e');
    }
  }

  Future<void> _saveTransactionLog(List<SyncTransaction> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = transactions.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_transactionLogKey, logJson);
    } catch (e) {
      debugPrint('❌ Error saving transaction log: $e');
    }
  }

  /// Clear all sync data (queue + transaction log)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_transactionLogKey);
      debugPrint('🗑️ Cleared all sync data');
    } catch (e) {
      debugPrint('❌ Error clearing sync data: $e');
    }
  }
}
