import '../models/sync_operation.dart';
import '../models/writing_file.dart';

/// Common interface every cloud sync provider (Supabase, WebDAV, iCloud, ...)
/// implements, so [SyncProvider] and callers never branch on provider type.
abstract class SyncBackend {
  Stream<SyncStatus> get statusStream;

  /// Whether this backend has credentials/session to sync with.
  bool get isSignedIn;

  Future<bool> get isOnline;

  /// Immediately upload one file. Used for the "sync right after save" path.
  Future<bool> syncFile(WritingFile file);

  Future<void> deleteFile(String fileId);

  /// Remote file listing, e.g. for merging with local files on load.
  Stream<List<WritingFile>> getFilesStream();

  /// Add an operation to the durable retry queue, syncing immediately if online.
  Future<void> queueFileSync(WritingFile file, SyncOperationType type);

  /// Drain the durable retry queue.
  Future<void> processSyncQueue();

  Future<Map<String, dynamic>> getSyncStats();

  /// Clear all local sync bookkeeping (queue, timestamps) - used on logout
  /// or when switching to a different backend.
  Future<void> clearSyncData();

  void dispose();
}
