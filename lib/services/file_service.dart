import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/writing_file.dart';
import '../providers/sync_provider.dart';
import '../services/supabase_cloud_sync_service.dart';

class FileService {
  final SupabaseCloudSyncService _cloudSync;
  static bool _migrationCompleted = false;

  FileService({SupabaseCloudSyncService? cloudSync})
      : _cloudSync = cloudSync ?? SupabaseCloudSyncService();

  Future<List<WritingFile>> getFiles(BuildContext context) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final isSignedIn = syncProvider.isSignedIn;

    try {
      // Migrate old files if they exist (only needs to run once)
      if (!_migrationCompleted) {
        await _migrateOldFiles();
        _migrationCompleted = true;
      }

      // Always get local files first to ensure they're preserved
      final localFiles = await _getLocalFiles();
      debugPrint('Found ${localFiles.length} local files');

      // If offline or not signed in, return local files only
      final isOnline = await _cloudSync.isOnline;
      if (!isOnline || !isSignedIn) {
        debugPrint(
            'Returning local files only (offline: ${!isOnline}, not signed in: ${!isSignedIn})');
        return localFiles;
      }

      // If online and signed in, try to get cloud files and merge
      try {
        final cloudFiles = await _cloudSync.getFilesStream().first.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Cloud files fetch timed out, returning local files');
            return <WritingFile>[];
          },
        );

        debugPrint('Found ${cloudFiles.length} cloud files');

        // Merge files, preserving local versions when in doubt
        return _mergeFiles(cloudFiles, localFiles);
      } catch (e) {
        debugPrint('Error getting cloud files: $e, returning local files');
        return localFiles;
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
      final directory = await getApplicationDocumentsDirectory();
      final writingFilesDir = Directory('${directory.path}/writing_files');

      // Check if the writing_files directory exists
      if (!await writingFilesDir.exists()) {
        debugPrint('Writing files directory does not exist');
        return [];
      }

      final files = await writingFilesDir.list().toList();

      return Future.wait(files
              .where((file) => file.path.endsWith('.text'))
              .map((file) async {
        final fileName = file.path.split('/').last;
        // Extract id from filename (filename format: {id}.text)
        final id = fileName.replaceAll('.text', '');

        // Get metadata from SharedPreferences
        final content = await File(file.path).readAsString();
        final lastModified = await File(file.path).lastModified();

        // Try to get name from metadata, fallback to id
        String name = id;
        try {
          final prefs = await SharedPreferences.getInstance();
          final metadataKey = 'file_metadata_$id';
          final metadata = prefs.getString(metadataKey);
          if (metadata != null) {
            final data = json.decode(metadata);
            name = data['name'] ?? id;
          }
        } catch (e) {
          debugPrint('Error reading metadata for file $id: $e');
        }

        return WritingFile(
          id: id,
          name: name,
          content: content,
          lastModified: lastModified,
        );
      }).whereType<Future<WritingFile>>())
          .then((files) => files.whereType<WritingFile>().toList());
    } catch (e) {
      debugPrint('Error reading local files: $e');
      return [];
    }
  }

  List<WritingFile> _mergeFiles(
      List<WritingFile> cloudFiles, List<WritingFile> localFiles) {
    final Map<String, WritingFile> mergedFiles = {};

    // Add local files first (prioritize local changes)
    for (var localFile in localFiles) {
      if (localFile.id.isNotEmpty) {
        // Ensure valid ID
        mergedFiles[localFile.id] = localFile;
      }
    }

    // Only merge cloud files if they're newer or don't exist locally
    for (var cloudFile in cloudFiles) {
      if (cloudFile.id.isEmpty) continue; // Skip invalid cloud files

      if (mergedFiles.containsKey(cloudFile.id)) {
        final localFile = mergedFiles[cloudFile.id]!;
        // Only replace with cloud version if it's significantly newer (more than 1 second)
        // This helps avoid issues with slight timestamp differences
        if (cloudFile.lastModified
            .isAfter(localFile.lastModified.add(const Duration(seconds: 1)))) {
          mergedFiles[cloudFile.id] = cloudFile;
          debugPrint(
              'Using cloud version of file ${cloudFile.id} (${cloudFile.name}) as it\'s newer');
        } else {
          debugPrint(
              'Keeping local version of file ${localFile.id} (${localFile.name})');
        }
      } else {
        // File doesn't exist locally, add cloud version
        mergedFiles[cloudFile.id] = cloudFile;
        debugPrint(
            'Adding cloud-only file ${cloudFile.id} (${cloudFile.name})');
      }
    }

    final result = mergedFiles.values.toList();
    debugPrint(
        'Merged files: ${result.length} total (${localFiles.length} local, ${cloudFiles.length} cloud)');
    return result;
  }

  // Future<void> _syncLocalChanges(List<WritingFile> files) async {
  //   for (var file in files) {
  //     await _cloudSync.syncFile(file);
  //   }
  // }

  Future<WritingFile> createFile(String name) async {
    try {
      final file = WritingFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        content: '',
      );

      // Always save locally first
      await file.writeContent('');
      debugPrint('File created locally: ${file.id}');

      // Try to sync to cloud if signed in and online
      try {
        final isOnline = await _cloudSync.isOnline;
        if (isOnline && _cloudSync.isSignedIn) {
          final syncSuccess = await _cloudSync.syncFile(file).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('Cloud sync timed out during file creation');
              return false;
            },
          );

          if (!syncSuccess) {
            // Store for later sync if cloud sync fails
            await _storePendingChange(file);
            debugPrint(
                'File created locally, cloud sync failed - stored for later sync');
          } else {
            debugPrint('File created and synced to cloud successfully');
          }
        } else {
          // Store for later sync when offline or not signed in
          await _storePendingChange(file);
          debugPrint('File created locally, stored for later sync');
        }
      } catch (e) {
        debugPrint('Error during cloud sync during file creation: $e');
        await _storePendingChange(file);
      }

      return file;
    } catch (e) {
      debugPrint('Error creating file: $e');
      throw Exception('Failed to create file: ${e.toString()}');
    }
  }

  Future<(bool, String)> saveFile(WritingFile file, String content) async {
    bool localSaveSuccess = false;
    String resultMessage = '';

    try {
      // Always save locally first - this is the most important operation
      await file.writeContent(content);

      // Verify the local save worked
      final savedContent = await file.readContent();
      if (savedContent != content) {
        throw Exception('Local content verification failed');
      }

      localSaveSuccess = true;
      debugPrint('File saved locally successfully');

      // Try to sync to cloud if signed in and online
      try {
        final isOnline = await _cloudSync.isOnline;
        if (isOnline && _cloudSync.isSignedIn) {
          final syncSuccess = await _cloudSync.syncFile(file).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('Cloud sync timed out');
              return false;
            },
          );

          if (syncSuccess) {
            resultMessage = 'File saved locally and synced to cloud';
          } else {
            // Store for later sync if cloud sync fails
            await _storePendingChange(file);
            resultMessage =
                'File saved locally, cloud sync failed - will retry later';
          }
        } else {
          // Store for later sync when offline or not signed in
          await _storePendingChange(file);
          if (!isOnline) {
            resultMessage = 'File saved locally (offline mode)';
          } else {
            resultMessage = 'File saved locally (not signed in)';
          }
        }
      } catch (e) {
        debugPrint('Error during cloud sync: $e');
        // Store for later sync if cloud sync fails
        await _storePendingChange(file);
        resultMessage =
            'File saved locally, cloud sync failed - will retry later';
      }

      return (true, resultMessage);
    } catch (e) {
      debugPrint('Error saving file: $e');
      if (localSaveSuccess) {
        return (true, 'File saved locally but with warnings: ${e.toString()}');
      } else {
        return (false, 'Failed to save file locally: ${e.toString()}');
      }
    }
  }

  Future<void> _storePendingChange(WritingFile file) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingChanges = prefs.getStringList('pending_changes') ?? [];

    // Add file ID to pending changes if not already present
    if (!pendingChanges.contains(file.id)) {
      pendingChanges.add(file.id);
      await prefs.setStringList('pending_changes', pendingChanges);
    }
  }

  Future<void> syncPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingChanges = prefs.getStringList('pending_changes') ?? [];

      if (pendingChanges.isEmpty) {
        debugPrint('No pending changes to sync');
        return;
      }

      debugPrint('Syncing ${pendingChanges.length} pending changes');
      final localFiles = await _getLocalFiles();
      final successfulSyncs = <String>[];

      for (String fileId in pendingChanges) {
        try {
          final file = localFiles.where((f) => f.id == fileId).firstOrNull;
          if (file != null) {
            final syncSuccess = await _cloudSync.syncFile(file).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint('Sync timeout for file $fileId');
                return false;
              },
            );

            if (syncSuccess) {
              successfulSyncs.add(fileId);
              debugPrint('Successfully synced file $fileId');
            } else {
              debugPrint('Failed to sync file $fileId');
            }
          } else {
            debugPrint('File $fileId not found locally, removing from pending');
            successfulSyncs
                .add(fileId); // Remove from pending since file doesn't exist
          }
        } catch (e) {
          debugPrint('Error syncing pending change for file $fileId: $e');
        }
      }

      // Remove only successfully synced files from pending changes
      if (successfulSyncs.isNotEmpty) {
        final remainingChanges = pendingChanges
            .where((id) => !successfulSyncs.contains(id))
            .toList();
        await prefs.setStringList('pending_changes', remainingChanges);
        debugPrint(
            'Removed ${successfulSyncs.length} successful syncs, ${remainingChanges.length} pending changes remain');
      }
    } catch (e) {
      debugPrint('Error in syncPendingChanges: $e');
    }
  }

  Future<void> deleteFile(WritingFile file) async {
    // Delete locally
    await file.delete();

    // Delete from cloud
    await _cloudSync.deleteFile(file.id);
  }

  Future<void> renameFile(WritingFile file, String newName) async {
    // Delete old local file
    await file.delete();

    final updatedFile = WritingFile(
      id: file.id,
      name: newName,
      content: await file.readContent(),
      lastModified: DateTime.now(),
    );

    // Save with new name
    await updatedFile.writeContent(await file.readContent());

    // Sync to cloud
    await _cloudSync.syncFile(updatedFile);
  }

  Future<void> _migrateOldFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = await directory.list().toList();

      final oldFiles =
          files.where((file) => file.path.endsWith('.txt')).toList();

      if (oldFiles.isEmpty) {
        debugPrint('No old .txt files found to migrate');
        return;
      }

      debugPrint('Found ${oldFiles.length} old .txt files to migrate');

      for (var oldFile in oldFiles) {
        try {
          final fileName = oldFile.path.split('/').last;
          // Extract id and name from old filename format
          final match = RegExp(r'(.+)_([^_]+)\.txt$').firstMatch(fileName);
          if (match != null) {
            final name = match.group(1)!;
            final id = match.group(2)!;
            final content = await File(oldFile.path).readAsString();
            final lastModified = await File(oldFile.path).lastModified();

            // Create new WritingFile with migrated data
            final migratedFile = WritingFile(
              id: id,
              name: name,
              content: content,
              lastModified: lastModified,
            );

            // Save in new format
            await migratedFile.writeContent(content);

            // Delete old file
            await File(oldFile.path).delete();

            debugPrint('Migrated file: $name (ID: $id)');
          }
        } catch (e) {
          debugPrint('Error migrating file ${oldFile.path}: $e');
        }
      }

      debugPrint('File migration completed');
    } catch (e) {
      debugPrint('Error during file migration: $e');
    }
  }
}
