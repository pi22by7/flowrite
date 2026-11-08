import '../../models/sync_operation.dart';
import '../../models/writing_file.dart';
import '../sync_backend.dart';
import '../sync_queue_service.dart';

/// Local-only mode never instantiates a network client or consumes pending edits.
class LocalSyncBackend implements SyncBackend {
  @override
  Stream<SyncStatus> get statusStream => const Stream.empty();
  @override
  bool get isSignedIn => false;
  @override
  Future<bool> get isOnline async => false;
  @override
  Future<bool> syncFile(WritingFile file) async => false;
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Stream<List<WritingFile>> getFilesStream() => Stream.value([]);
  @override
  Future<void> queueFileSync(WritingFile file, SyncOperationType type) async {}
  @override
  Future<void> processSyncQueue() async {}
  @override
  Future<Map<String, dynamic>> getSyncStats() =>
      SyncQueueService().getQueueStats();
  @override
  Future<void> clearSyncData() async {}
  @override
  void dispose() {}
}
