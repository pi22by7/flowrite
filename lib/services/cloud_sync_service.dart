// lib/services/cloud_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/writing_file.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _lastSyncKey = 'last_sync_timestamp';

  String get _userId => _auth.currentUser?.uid ?? '';

  Future<void> syncFile(WritingFile file) async {
    if (_userId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('files')
        .doc(file.id)
        .set({
      'name': file.name,
      'content': await file.readContent(),
      'lastModified': FieldValue.serverTimestamp(),
    });

    // Update last sync timestamp
    await _updateLastSyncTime();
  }

  Future<void> deleteFile(String fileId) async {
    if (_userId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('files')
        .doc(fileId)
        .delete();
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
    if (_userId.isEmpty) return;

    try {
      final lastSync = await _getLastSyncTime();

      // Get all local files that were modified after the last sync
      final localFiles = await _getModifiedLocalFiles(lastSync);

      // Batch write to Firestore
      final batch = _firestore.batch();
      final userFilesRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('files');

      for (var file in localFiles) {
        batch.set(userFilesRef.doc(file.id), {
          'name': file.name,
          'content': await file.readContent(),
          'lastModified': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      await _updateLastSyncTime();
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
    // Implement this based on your local storage implementation
    // This should return all files that were modified after the 'since' timestamp
    return [];
  }
}
