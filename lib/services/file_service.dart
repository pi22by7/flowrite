import 'package:flutter/material.dart';
import '../models/writing_file.dart';
import '../services/sync_queue_service.dart';
import '../models/sync_operation.dart';
import '../providers/sync_provider.dart';
import '../providers/settings_provider.dart';
import '../services/sync_backend.dart';
import '../services/storage_service.dart';

class FileService {
  final SyncProvider _syncProvider;
  late final StorageService _storage;
  static bool _migrationCompleted = false;

  /// Always read the live backend fresh from [_syncProvider] rather than
  /// caching it - otherwise a mid-session backend switch in Settings would
  /// leave this class syncing against a stale, disposed backend.
  SyncBackend get _cloudSync => _syncProvider.activeBackend;

  FileService({required SyncProvider syncProvider})
      : _syncProvider = syncProvider {
    _storage = StorageService.create();
  }

  Future<List<WritingFile>> getFiles(BuildContext context,
      {bool includeRemote = false}) async {
    final isConfigured = _syncProvider.isCloudConfigured;
    final backend = _cloudSync;

    try {
      // Migrate old files if they exist (only needs to run once)
      if (!_migrationCompleted) {
        await _migrateOldFiles();
        _migrationCompleted = true;
      }

      // Always get local files first to ensure they're preserved
      final localFiles = await _getLocalFiles();
      debugPrint('Found ${localFiles.length} local files');

      // If offline or the active backend isn't configured, return local files only
      if (!includeRemote || !isConfigured) return localFiles;
      final isOnline = await backend.isOnline;
      if (!isOnline || !isConfigured) {
        debugPrint(
            'Returning local files only (offline: ${!isOnline}, not configured: ${!isConfigured})');
        return localFiles;
      }

      // If online and configured, try to get cloud files and merge
      try {
        await for (final cloudFiles
            in backend.getFilesStream().timeout(const Duration(seconds: 30))) {
          if (!identical(backend, _syncProvider.activeBackend)) break;
          await _mergeFiles(cloudFiles, await _getLocalFiles(), backend);
          // Supabase is a continuous stream; WebDAV ends after its listing.
          if (_syncProvider.backendType != SyncBackendType.webdav) break;
        }
        return await _getLocalFiles();
      } catch (e) {
        debugPrint('Error getting cloud files: $e, returning local files');
        return await _getLocalFiles();
      }
    } catch (e) {
      debugPrint('Error getting files: $e');
      // If there's any error, try to return at least local files
      try {
        return await _getLocalFiles();
      } catch (localError) {
        debugPrint('Error getting local files as fallback: $localError');
        return [];
      }
    }
  }

  Future<List<WritingFile>> _getLocalFiles() async {
    try {
      final fileIds = await _storage.getAllFileIds();

      if (fileIds.isEmpty) {
        debugPrint('No local files found');
        return [];
      }

      final files = <WritingFile>[];

      for (final id in fileIds) {
        try {
          final content = await _storage.readContent(id);
          final metadata = await _storage.getMetadata(id);

          if (metadata?['deleted'] == true) continue;
          String name = id;
          DateTime lastModified = DateTime.now();

          if (metadata != null) {
            name = metadata['name'] ?? id;
            final lastModifiedStr = metadata['lastModified'];
            if (lastModifiedStr != null) {
              lastModified = DateTime.parse(lastModifiedStr);
            }
          }

          files.add(WritingFile(
            id: id,
            name: name,
            content: content,
            lastModified: lastModified,
          ));
        } catch (e) {
          debugPrint('Error reading file $id: $e');
        }
      }

      debugPrint('Successfully loaded ${files.length} local files');
      return files;
    } catch (e) {
      debugPrint('Error reading local files: $e');
      return [];
    }
  }

  Future<List<WritingFile>> _mergeFiles(List<WritingFile> cloudFiles,
      List<WritingFile> localFiles, SyncBackend backend) async {
    final Map<String, WritingFile> mergedFiles = {};

    // Add local files first (prioritize local changes)
    for (var localFile in localFiles) {
      if (localFile.id.isNotEmpty) {
        // Ensure valid ID
        mergedFiles[localFile.id] = localFile;
      }
    }

    final storage = StorageService.create();
    for (final cloudFile in cloudFiles) {
      if (!identical(backend, _syncProvider.activeBackend)) break;
      if (cloudFile.id.isEmpty) continue;
      final metadata = await storage.getMetadata(cloudFile.id);
      // A remote download must never overwrite an edit made while the request
      // was in flight. The outbox will resolve it during the next upload.
      if (metadata?['pendingSync'] != null) continue;
      if (metadata?['deleted'] == true && !cloudFile.isDeleted) continue;
      final local = mergedFiles[cloudFile.id];
      if (cloudFile.isDeleted ||
          local == null ||
          !local.lastModified.isAfter(cloudFile.lastModified)) {
        if (!await cloudFile.saveRemote()) continue;
        if (cloudFile.isDeleted) {
          mergedFiles.remove(cloudFile.id);
        } else {
          mergedFiles[cloudFile.id] = cloudFile;
        }
      }
    }

    final result = mergedFiles.values.toList();
    debugPrint(
        'Merged files: ${result.length} total (${localFiles.length} local, ${cloudFiles.length} cloud)');
    return _getLocalFiles();
  }

  // Future<void> _syncLocalChanges(List<WritingFile> files) async {
  //   for (var file in files) {
  //     await _cloudSync.syncFile(file);
  //   }
  // }

  Future<WritingFile> createFile(String name) async {
    final file = WritingFile(
        id: SyncQueueService.newOperation('', SyncOperationType.create).id,
        name: name,
        content: '');
    await file.writeContent('');
    _syncProvider.scheduleSync();
    return file;
  }

  Future<(bool, String)> saveFile(WritingFile file, String content) async {
    try {
      await file.writeContent(content);
      _syncProvider.scheduleSync();
      return (true, 'File saved locally');
    } catch (e) {
      return (false, 'Failed to save file locally: $e');
    }
  }

  Future<void> deleteFile(WritingFile file) async {
    await file.delete();
    _syncProvider.scheduleSync();
  }

  Future<void> renameFile(WritingFile file, String newName) async {
    // Update only metadata: a rename must not overwrite a simultaneous autosave.
    final modified = DateTime.now().toUtc();
    await _storage.updateMetadata(file.id, (metadata) {
      metadata['name'] = newName;
      metadata['lastModified'] = modified.toIso8601String();
      metadata['pendingSync'] =
          SyncQueueService.newOperation(file.id, SyncOperationType.update)
              .toJson();
    });
    file.name = newName;
    file.lastModified = modified;
    _syncProvider.scheduleSync();
  }

  Future<void> _migrateOldFiles() async {
    try {
      // Only attempt migration on mobile platforms (web doesn't have old files to migrate)
      if (_storage is! FileSystemStorageService) {
        debugPrint('Skipping migration on web platform');
        return;
      }

      // For mobile platforms, we could migrate old .txt files here if needed
      debugPrint('Migration check completed (mobile platform)');
    } catch (e) {
      debugPrint('Error during file migration: $e');
    }
  }
}
