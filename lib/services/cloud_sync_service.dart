import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/writing_file.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _localFilesKey = 'local_files';

  String get _userId => _auth.currentUser?.uid ?? '';

  bool get isSignedIn => _userId.isNotEmpty;

  Future<bool> get isOnline async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Just a lightweight check
        await transaction.get(_firestore.collection('health').doc('status'));
      }, timeout: const Duration(seconds: 5));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncFile(WritingFile file) async {
    if (_userId.isEmpty) {
      debugPrint('User not signed in, cannot sync file ${file.id}');
      return false;
    }

    try {
      // Check online status first
      final isOnline = await this.isOnline;
      if (!isOnline) {
        debugPrint('Device is offline, cannot sync file ${file.id}');
        return false;
      }

      // Read content with error handling
      String content;
      try {
        content = await file.readContent();
      } catch (e) {
        debugPrint('Error reading content for file ${file.id}: $e');
        return false;
      }

      // Update cloud with timeout
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('files')
          .doc(file.id)
          .set({
        'name': file.name,
        'content': content,
        'lastModified': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Firestore write timeout');
        },
      );

      // Update local metadata
      await _updateLocalFileMetadata(file);

      // Update last sync timestamp
      await _updateLastSyncTime();

      debugPrint('Successfully synced file ${file.id} to cloud');
      return true;
    } catch (e) {
      debugPrint('Error syncing file ${file.id} to cloud: $e');
      return false;
    }
  }

  Future<void> deleteFile(String fileId) async {
    if (_userId.isEmpty) return;

    try {
      // Delete from cloud
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('files')
          .doc(fileId)
          .delete();

      // Remove from local metadata
      await _removeLocalFileMetadata(fileId);
    } catch (e) {
      debugPrint('Error deleting file: $e');
      rethrow;
    }
  }

  Stream<List<WritingFile>> getFilesStream() {
    if (_userId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('files')
        .orderBy('lastModified', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WritingFile(
                  id: doc.id,
                  name: doc['name'],
                  content: doc['content'],
                ))
            .toList());
  }

  Future<void> syncPendingChanges() async {
    if (_userId.isEmpty) {
      debugPrint('User not signed in, cannot sync pending changes');
      return;
    }

    try {
      final lastSync = await _getLastSyncTime();
      final localFiles = await _getModifiedLocalFiles(lastSync);

      if (localFiles.isEmpty) {
        debugPrint('No modified local files to sync');
        return;
      }

      debugPrint('Syncing ${localFiles.length} modified files to cloud');

      // Check online status before attempting batch write
      final isOnline = await this.isOnline;
      if (!isOnline) {
        debugPrint('Device is offline, cannot sync to cloud');
        return;
      }

      // Batch write to Firestore with timeout
      final batch = _firestore.batch();
      final userFilesRef =
          _firestore.collection('users').doc(_userId).collection('files');

      for (var file in localFiles) {
        try {
          final content = await file.readContent();
          batch.set(
              userFilesRef.doc(file.id),
              {
                'name': file.name,
                'content': content,
                'lastModified': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error preparing file ${file.id} for sync: $e');
        }
      }

      await batch.commit().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Batch commit timeout');
        },
      );

      // Update local metadata for all synced files
      for (var file in localFiles) {
        try {
          await _updateLocalFileMetadata(file);
        } catch (e) {
          debugPrint('Error updating local metadata for file ${file.id}: $e');
        }
      }

      await _updateLastSyncTime();
      debugPrint('Successfully synced ${localFiles.length} files to cloud');
    } catch (e) {
      debugPrint('Error syncing pending changes: $e');
      rethrow;
    }
  }

  Future<DateTime> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime(2000); // Default to old date if never synced
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<WritingFile>> _getModifiedLocalFiles(DateTime since) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localFilesJson = prefs.getStringList(_localFilesKey) ?? [];

      final List<WritingFile> modifiedFiles = [];

      for (String fileJson in localFilesJson) {
        final Map<String, dynamic> fileData = json.decode(fileJson);
        final WritingFile file = WritingFile.fromJson(fileData);

        // Check if file was modified after last sync
        if (file.lastModified.isAfter(since)) {
          modifiedFiles.add(file);
        }
      }

      return modifiedFiles;
    } catch (e) {
      debugPrint('Error getting modified files: $e');
      return [];
    }
  }

  Future<void> _updateLocalFileMetadata(WritingFile file) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> localFilesJson = prefs.getStringList(_localFilesKey) ?? [];

      // Remove old metadata if exists
      localFilesJson.removeWhere((fileJson) {
        final Map<String, dynamic> fileData = json.decode(fileJson);
        return fileData['id'] == file.id;
      });

      // Add new metadata
      localFilesJson.add(json.encode(file.toJson()));

      await prefs.setStringList(_localFilesKey, localFilesJson);
    } catch (e) {
      debugPrint('Error updating local file metadata: $e');
    }
  }

  Future<void> _removeLocalFileMetadata(String fileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> localFilesJson = prefs.getStringList(_localFilesKey) ?? [];

      localFilesJson.removeWhere((fileJson) {
        final Map<String, dynamic> fileData = json.decode(fileJson);
        return fileData['id'] == fileId;
      });

      await prefs.setStringList(_localFilesKey, localFilesJson);
    } catch (e) {
      debugPrint('Error removing local file metadata: $e');
    }
  }

  // Add method to clear all sync data (useful for logout)
  Future<void> clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSyncKey);
      await prefs.remove(_localFilesKey);
    } catch (e) {
      debugPrint('Error clearing sync data: $e');
    }
  }
}
