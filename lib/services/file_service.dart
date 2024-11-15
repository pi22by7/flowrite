// lib/services/file_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/writing_file.dart';
import '../providers/sync_provider.dart';
import '../services/cloud_sync_service.dart';

class FileService {
  final CloudSyncService _cloudSync;

  FileService({CloudSyncService? cloudSync})
      : _cloudSync = cloudSync ?? CloudSyncService();

  Future<List<WritingFile>> getFiles(BuildContext context) async {
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      if (syncProvider.isSignedIn) {
        // First, get files from cloud
        final cloudFiles = await _cloudSync.getFilesStream().first;

        // Then, get local files
        final localFiles = await _getLocalFiles();

        // Merge cloud and local files, prioritizing cloud versions
        final mergedFiles = _mergeFiles(cloudFiles, localFiles);

        // Sync any local changes to cloud
        await _syncLocalChanges(mergedFiles);

        return mergedFiles;
      } else {
        // If not signed in, return only local files
        return await _getLocalFiles();
      }
    } catch (e) {
      debugPrint('Error getting files: $e');
      return [];
    }
  }

  Future<List<WritingFile>> _getLocalFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = await directory.list().toList();
    return files
        .where((file) => file.path.endsWith('.txt'))
        .map((file) => WritingFile(
      id: file.path.split('/').last.split('.').first,
      name: file.path.split('/').last.split('.').first,
      content: File(file.path).readAsStringSync(),
    ))
        .toList();
  }

  List<WritingFile> _mergeFiles(List<WritingFile> cloudFiles, List<WritingFile> localFiles) {
    final Map<String, WritingFile> mergedFiles = {};

    // Add cloud files first, prioritizing them
    for (var file in cloudFiles) {
      mergedFiles[file.id] = file;
    }

    // Add local files, but only if they don't exist in cloud or are newer
    for (var file in localFiles) {
      if (!mergedFiles.containsKey(file.id) ||
          file.lastModified.isAfter(mergedFiles[file.id]!.lastModified)) {
        mergedFiles[file.id] = file;
      }
    }

    return mergedFiles.values.toList();
  }

  Future<void> _syncLocalChanges(List<WritingFile> files) async {
    for (var file in files) {
      await _cloudSync.syncFile(file);
    }
  }

  Future<WritingFile> createFile(String name) async {
    final file = WritingFile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      content: '',
    );

    // Save locally
    await file.writeContent('');

    // Sync to cloud
    await _cloudSync.syncFile(file);

    return file;
  }

  Future<void> saveFile(WritingFile file, String content) async {
    // Save locally
    await file.writeContent(content);

    // Sync to cloud
    await _cloudSync.syncFile(file);
  }

  Future<void> deleteFile(WritingFile file) async {
    // Delete locally
    await file.delete();

    // Delete from cloud
    await _cloudSync.deleteFile(file.id);
  }

  Future<void> renameFile(WritingFile file, String newName) async {
    final updatedFile = WritingFile(
      id: file.id,
      name: newName,
      content: await file.readContent(),
    );

    // Save locally
    await updatedFile.writeContent(await file.readContent());

    // Sync to cloud
    await _cloudSync.syncFile(updatedFile);
  }
}
