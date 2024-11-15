// lib/services/file_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/writing_file.dart';
import '../providers/sync_provider.dart';
import '../services/cloud_sync_service.dart';

class FileService {
  final CloudSyncService _cloudSync;

  FileService({CloudSyncService? cloudSync})
      : _cloudSync = cloudSync ?? CloudSyncService();

  Future<List<WritingFile>> getFiles(BuildContext context) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final isSignedIn = syncProvider.isSignedIn;

    try {
      // Get local files first
      final localFiles = await _getLocalFiles();


      // If offline or not signed in, return local files only
      final isOnline = await _cloudSync.isOnline;
      if (!isOnline || !isSignedIn) {
        debugPrint('Returning local files only');
        return localFiles;
      }

      // If online, get cloud files
      final cloudFiles = await _cloudSync.getFilesStream().first;

      // Merge files, preferring local versions when offline
      return _mergeFiles(cloudFiles, localFiles);
    } catch (e) {
      debugPrint('Error getting files: $e');
      return [];
    }
  }

  Future<List<WritingFile>> _getLocalFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = await directory.list().toList();

      return Future.wait(files
          .where((file) => file.path.endsWith('.txt'))
          .map((file) async {
        final fileName = file.path.split('/').last;
        // Extract id and name from filename
        final match = RegExp(r'(.+)_([^_]+)\.txt$').firstMatch(fileName);
        if (match != null) {
          final name = match.group(1)!;
          final id = match.group(2)!;
          final content = await File(file.path).readAsString();
          return WritingFile(
            id: id,
            name: name,
            content: content,
            lastModified: await File(file.path).lastModified(),
          );
        }
        return null;
      })
          .whereType<Future<WritingFile>>())
          .then((files) => files.whereType<WritingFile>().toList());
    } catch (e) {
      debugPrint('Error reading local files: $e');
      return [];
    }
  }

  List<WritingFile> _mergeFiles(List<WritingFile> cloudFiles, List<WritingFile> localFiles) {
    final Map<String, WritingFile> mergedFiles = {};

    // Add local files first (prioritize local changes)
    for (var localFile in localFiles) {
      mergedFiles[localFile.id] = localFile;
    }

    // Only merge cloud files if they're newer
    for (var cloudFile in cloudFiles) {
      if (mergedFiles.containsKey(cloudFile.id)) {
        final localFile = mergedFiles[cloudFile.id]!;
        if (cloudFile.lastModified.isAfter(localFile.lastModified)) {
          mergedFiles[cloudFile.id] = cloudFile;
        }
      } else {
        mergedFiles[cloudFile.id] = cloudFile;
      }
    }

    return mergedFiles.values.toList();
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

      // Save locally first
      await file.writeContent('');

      // Try to sync to cloud
      final isOnline = await _cloudSync.isOnline;
      if (isOnline) {
        await _cloudSync.syncFile(file);
      }

      return file;
    } catch (e) {
      debugPrint('Error creating file: $e');
      throw Exception('Failed to create file: ${e.toString()}');
    }
  }


  Future<(bool, String)> saveFile(WritingFile file, String content) async {
    try {
      // Save locally first
      await file.writeContent(content);

      // Verify the save
      final savedContent = await file.readContent();
      if (savedContent != content) {
        throw Exception('Content verification failed');
      }

      // Try to sync to cloud if online
      final isOnline = await _cloudSync.isOnline;
      if (isOnline) {
        final syncSuccess = await _cloudSync.syncFile(file);
        if (!syncSuccess) {
          // Store for later sync if cloud sync fails
          await _storePendingChange(file);
        }
        return (true, syncSuccess
            ? 'File saved locally and synced to cloud'
            : 'File saved locally, will sync later');
      }

      // Store for later sync
      await _storePendingChange(file);
      return (true, 'File saved locally (offline mode)');
    } catch (e) {
      debugPrint('Error saving file: $e');
      return (false, 'Error saving file: ${e.toString()}');
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
    final prefs = await SharedPreferences.getInstance();
    final pendingChanges = prefs.getStringList('pending_changes') ?? [];

    if (pendingChanges.isEmpty) return;

    for (String fileId in pendingChanges) {
      try {
        final localFiles = await _getLocalFiles();
        final file = localFiles.firstWhere((f) => f.id == fileId);
        await _cloudSync.syncFile(file);
      } catch (e) {
        debugPrint('Error syncing pending change for file $fileId: $e');
      }
    }

    // Clear pending changes after successful sync
    await prefs.setStringList('pending_changes', []);
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
}
