import 'dart:convert';
import 'package:idb_shim/idb.dart';
import 'package:synchronized/synchronized.dart';
import 'idb_factory_stub.dart'
    if (dart.library.js_interop) 'idb_factory_web.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a [FileSystemStorageService.migrateStorageLocation] call.
class MigrationResult {
  final int migratedCount;
  final List<String> failedIds;

  MigrationResult({required this.migratedCount, required this.failedIds});

  bool get success => failedIds.isEmpty;
}

abstract class StorageService {
  static final _lock = Lock();
  static StorageService? _webStorage;
  @visibleForTesting
  static StorageService Function()? overrideFactory;

  /// Commit document and pending operation together. Web overrides this with an
  /// IndexedDB transaction; native writes are serialized within this process.
  Future<void> saveDocument(
          String id, String content, Map<String, dynamic> metadata) =>
      _lock.synchronized(() async {
        final previous = await getMetadata(id) ?? <String, dynamic>{};
        await writeContent(id, content);
        await saveMetadata(id, {...previous, ...metadata});
      });

  Future<Map<String, dynamic>?> readDocument(String id) async {
    final metadata = await getMetadata(id);
    if (metadata == null) return null;
    return {'content': await readContent(id), 'metadata': metadata};
  }

  Future<bool> applyRemote(
          String id, String content, Map<String, dynamic> metadata,
          {String? expectedOperationId}) =>
      _lock.synchronized(() async {
        final previous = await getMetadata(id) ?? <String, dynamic>{};
        if (!_canApplyRemote(previous, metadata, expectedOperationId)) {
          return false;
        }
        await writeContent(id, content);
        await saveMetadata(id, {...previous, ...metadata, 'pendingSync': null});
        return true;
      });

  static bool _canApplyRemote(Map<String, dynamic> previous,
      Map<String, dynamic> incoming, String? expectedOperationId) {
    final pending = previous['pendingSync'] as Map?;
    if (expectedOperationId != null) {
      return pending?['id'] == expectedOperationId;
    }
    if (pending != null) return false;
    if (incoming['deleted'] == true) return true;
    if (previous['deleted'] == true && incoming['deleted'] != true) {
      return false;
    }
    final localTime =
        DateTime.tryParse(previous['lastModified'] as String? ?? '');
    final remoteTime =
        DateTime.tryParse(incoming['lastModified'] as String? ?? '');
    return localTime == null ||
        remoteTime != null && !localTime.isAfter(remoteTime);
  }

  Future<void> updateMetadata(
          String id, void Function(Map<String, dynamic>) update) =>
      _lock.synchronized(() async {
        final metadata = await getMetadata(id) ?? <String, dynamic>{};
        update(metadata);
        await saveMetadata(id, metadata);
      });

  Future<void> writeContent(String id, String content);
  Future<String> readContent(String id);
  Future<void> deleteContent(String id);
  Future<List<String>> getAllFileIds();
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata);
  Future<Map<String, dynamic>?> getMetadata(String id);

  static StorageService create() {
    if (overrideFactory != null) return overrideFactory!();
    if (kIsWeb) {
      debugPrint('Creating WebStorageService for web platform');
      return _webStorage ??= IndexedDbStorageService();
    } else {
      debugPrint('Creating FileSystemStorageService for mobile platform');
      return FileSystemStorageService();
    }
  }
}

class FileSystemStorageService extends StorageService {
  static const String fileExtension = '.text';
  static const String _customSavePathKey = 'customSavePath';

  Future<String> get _defaultPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/writing_files';
  }

  Future<String> get _localPath async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString(_customSavePathKey);
      final path = (customPath != null && customPath.isNotEmpty)
          ? customPath
          : await _defaultPath;
      await Directory(path).create(recursive: true);
      debugPrint('Local path: $path');
      return path;
    } catch (e) {
      debugPrint('Error getting local path: $e');
      rethrow;
    }
  }

  Future<File> _getFile(String id) async {
    final path = await _localPath;
    return File('$path/$id$fileExtension');
  }

  Future<File> _recordFile(String id) async =>
      File('${await _localPath}/$id.flowrite.json');

  Future<Map<String, dynamic>?> _record(String id) async {
    final file = await _recordFile(id);
    if (!await file.exists()) return null;
    return Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map);
  }

  Future<void> _commit(
      String id, String content, Map<String, dynamic> metadata) async {
    final file = await _recordFile(id);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
        jsonEncode({'content': content, 'metadata': metadata}),
        flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> saveDocument(
          String id, String content, Map<String, dynamic> metadata) =>
      StorageService._lock.synchronized(() async {
        await _commit(id, content, {...?await getMetadata(id), ...metadata});
      });

  @override
  Future<Map<String, dynamic>?> readDocument(String id) async =>
      await _record(id) ?? await super.readDocument(id);

  @override
  Future<void> updateMetadata(
          String id, void Function(Map<String, dynamic>) update) =>
      StorageService._lock.synchronized(() async {
        final metadata = await getMetadata(id) ?? <String, dynamic>{};
        update(metadata);
        await _commit(id, await readContent(id), metadata);
      });

  @override
  Future<bool> applyRemote(
          String id, String content, Map<String, dynamic> metadata,
          {String? expectedOperationId}) =>
      StorageService._lock.synchronized(() async {
        final previous = await getMetadata(id) ?? <String, dynamic>{};
        if (!StorageService._canApplyRemote(
            previous, metadata, expectedOperationId)) {
          return false;
        }
        await _commit(
            id, content, {...previous, ...metadata, 'pendingSync': null});
        return true;
      });

  /// Copies every file (content + metadata) from the current save location
  /// to [newBasePath], verifies each copy, then deletes the originals.
  /// Never deletes before a successful, verified copy.
  Future<MigrationResult> migrateStorageLocation(String newBasePath) =>
      StorageService._lock
          .synchronized(() => _migrateStorageLocation(newBasePath));

  Future<MigrationResult> _migrateStorageLocation(String newBasePath) async {
    final oldPath = await _localPath;
    if (oldPath == newBasePath) {
      return MigrationResult(migratedCount: 0, failedIds: []);
    }

    await Directory(newBasePath).create(recursive: true);

    final oldDir = Directory(oldPath);
    final failedIds = <String>[];
    final migratedIds = <String>{};

    if (await oldDir.exists()) {
      final files = await oldDir
          .list()
          .where((f) =>
              f.path.endsWith(fileExtension) ||
              f.path.endsWith('.flowrite.json'))
          .toList();

      for (final entity in files) {
        final fileName = entity.path.split('/').last;
        final id = fileName.endsWith('.flowrite.json')
            ? fileName.substring(0, fileName.length - '.flowrite.json'.length)
            : fileName.substring(0, fileName.length - fileExtension.length);
        try {
          final oldFile = File(entity.path);
          final content = await oldFile.readAsString();

          final newFile = File('$newBasePath/$fileName');
          await newFile.writeAsString(content,
              mode: FileMode.write, flush: true);

          final verifiedContent = await newFile.readAsString();
          if (verifiedContent != content) {
            failedIds.add(id);
            continue;
          }

          migratedIds.add(id);
        } catch (e) {
          debugPrint('Error migrating file $id: $e');
          failedIds.add(id);
        }
      }
    }

    if (failedIds.isNotEmpty) {
      debugPrint(
          'Migration had ${failedIds.length} failures, aborting cleanup of old files');
      return MigrationResult(
          migratedCount: migratedIds.length, failedIds: failedIds);
    }

    // All files verified copied — safe to persist the new path and clean up old ones.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customSavePathKey, newBasePath);

    if (await oldDir.exists()) {
      final files = await oldDir
          .list()
          .where((f) =>
              f.path.endsWith(fileExtension) ||
              f.path.endsWith('.flowrite.json'))
          .toList();
      for (final entity in files) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Error deleting old file ${entity.path}: $e');
        }
      }
    }

    return MigrationResult(
        migratedCount: migratedIds.length, failedIds: failedIds);
  }

  @override
  Future<void> writeContent(String id, String content) =>
      saveDocument(id, content, {});

  @override
  Future<String> readContent(String id) async {
    try {
      final record = await _record(id);
      if (record != null) return record['content'] as String;
      final file = await _getFile(id);

      if (await file.exists()) {
        final fileContent = await file.readAsString();
        debugPrint('File read successfully from: ${file.path}');
        debugPrint('Content length: ${fileContent.length}');
        return fileContent;
      }

      debugPrint('File does not exist at: ${file.path}');
      return '';
    } catch (e) {
      debugPrint('Error reading file: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteContent(String id) async {
    try {
      final recordFile = await _recordFile(id);
      if (await recordFile.exists()) await recordFile.delete();
      final file = await _getFile(id);
      if (await file.exists()) {
        await file.delete();
        debugPrint('File deleted: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  @override
  Future<List<String>> getAllFileIds() async {
    try {
      final path = await _localPath;
      final writingFilesDir = Directory(path);

      if (!await writingFilesDir.exists()) {
        debugPrint('Writing files directory does not exist');
        return [];
      }

      final files = await writingFilesDir.list().toList();

      return files
          .where((file) =>
              file.path.endsWith(fileExtension) ||
              file.path.endsWith('.flowrite.json'))
          .map((file) {
            final fileName = file.path.split('/').last;
            return fileName.endsWith('.flowrite.json')
                ? fileName.substring(
                    0, fileName.length - '.flowrite.json'.length)
                : fileName.substring(0, fileName.length - fileExtension.length);
          })
          .toSet()
          .toList();
    } catch (e) {
      debugPrint('Error getting file IDs: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata) =>
      StorageService._lock.synchronized(
          () async => _commit(id, await readContent(id), metadata));

  @override
  Future<Map<String, dynamic>?> getMetadata(String id) async {
    try {
      final record = await _record(id);
      if (record != null) {
        return Map<String, dynamic>.from(record['metadata'] as Map);
      }
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      final metadata = prefs.getString(key);
      if (metadata != null) {
        return json.decode(metadata);
      }
    } catch (e) {
      debugPrint('Error getting metadata: $e');
      rethrow;
    }
    return null;
  }
}

class WebStorageService extends StorageService {
  @override
  Future<void> writeContent(String id, String content) async {
    try {
      debugPrint(
          'Web: Attempting to write content for file $id, length: ${content.length}');
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_content_$id';
      final success = await prefs.setString(key, content);
      debugPrint('Web: Content save result for file $id: $success');

      // Verify the write worked
      final savedContent = prefs.getString(key);
      debugPrint(
          'Web: Verification - saved content length: ${savedContent?.length ?? 0}');
    } catch (e) {
      debugPrint('Error writing web content: $e');
      rethrow;
    }
  }

  @override
  Future<String> readContent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_content_$id';
      final content = prefs.getString(key) ?? '';
      debugPrint('Web: Content read for file $id, length: ${content.length}');
      return content;
    } catch (e) {
      debugPrint('Error reading web content: $e');
      return '';
    }
  }

  @override
  Future<void> deleteContent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contentKey = 'file_content_$id';
      final metadataKey = 'file_metadata_$id';

      await prefs.remove(contentKey);
      await prefs.remove(metadataKey);
      debugPrint('Web: Content and metadata deleted for file $id');
    } catch (e) {
      debugPrint('Error deleting web content: $e');
    }
  }

  @override
  Future<List<String>> getAllFileIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      final fileIds = keys
          .where((key) => key.startsWith('file_content_'))
          .map((key) => key.replaceFirst('file_content_', ''))
          .toList();

      debugPrint('Web: Found ${fileIds.length} file IDs');
      return fileIds;
    } catch (e) {
      debugPrint('Error getting web file IDs: $e');
      return [];
    }
  }

  @override
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      await prefs.setString(key, json.encode(metadata));
      debugPrint('Web: Metadata saved for file $id');
    } catch (e) {
      debugPrint('Error saving web metadata: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getMetadata(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'file_metadata_$id';
      final metadata = prefs.getString(key);
      if (metadata != null) {
        return json.decode(metadata);
      }
    } catch (e) {
      debugPrint('Error getting web metadata: $e');
    }
    return null;
  }
}

/// Documents and their pending sync operation share one IndexedDB record.
class IndexedDbStorageService extends StorageService {
  final IdbFactory? factory;
  final String databaseName;
  Future<Database>? _opening;
  IndexedDbStorageService(
      {this.factory, this.databaseName = 'flowrite_documents'});

  Future<Database> get _database => _opening ??= _open();

  Future<Database> _open() async {
    final db = await (factory ?? browserDatabaseFactory)
        .open(databaseName, version: 1, onUpgradeNeeded: (event) {
      event.database.createObjectStore('documents');
      event.database.createObjectStore('settings');
    });
    try {
      // Once migrated, retained preferences are recovery copies only. Do not
      // parse them again: an old tab or damaged backup must not block startup.
      final check = db.transaction('settings', idbModeReadOnly);
      final migrated =
          await check.objectStore('settings').getObject('legacyMigrated');
      await check.completed;
      if (migrated == true) return db;
      final prefs = await SharedPreferences.getInstance();
      // Read the legacy snapshot before opening a write transaction. Never await
      // non-IDB work inside a browser transaction (it would auto-commit).
      final records = <String, Map<String, dynamic>>{};
      for (final key
          in prefs.getKeys().where((k) => k.startsWith('file_content_'))) {
        final id = key.substring('file_content_'.length);
        records[id] = {
          'content': prefs.getString(key) ?? '',
          'metadata': {
            'id': id,
            'name': id,
            'lastModified': DateTime.now().toUtc().toIso8601String(),
            ...Map<String, dynamic>.from(
                jsonDecode(prefs.getString('file_metadata_$id') ?? '{}')
                    as Map),
          },
        };
      }
      final legacyQueue = prefs.getStringList('sync_queue') ?? [];
      for (final value in legacyQueue) {
        final op = Map<String, dynamic>.from(jsonDecode(value) as Map);
        final id = op['fileId'] as String;
        records.putIfAbsent(
            id,
            () => {
                  'content': '',
                  'metadata': {
                    'id': id,
                    'name': id,
                    'lastModified': op['createdAt'],
                    'deleted': op['type'] == 'delete'
                  },
                });
        final metadata = records[id]!['metadata'] as Map;
        metadata['pendingSync'] = op;
        if (op['type'] == 'delete') metadata['deleted'] = true;
      }
      final tx =
          db.transactionList(['documents', 'settings'], idbModeReadWrite);
      final settings = tx.objectStore('settings');
      if (await settings.getObject('legacyMigrated') != true) {
        final store = tx.objectStore('documents');
        for (final entry in records.entries) {
          if (await store.getObject(entry.key) == null) {
            await store.put(entry.value, entry.key);
          }
        }
        await settings.put(true, 'legacyMigrated');
      }
      await tx.completed;
      return db;
    } catch (_) {
      db.close();
      _opening = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _read(String id) async {
    final db = await _database;
    final tx = db.transaction('documents', idbModeReadOnly);
    final value = await tx.objectStore('documents').getObject(id);
    await tx.completed;
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<void> _update(
      String id, void Function(Map<String, dynamic>) change) async {
    final db = await _database;
    final tx = db.transaction('documents', idbModeReadWrite);
    final store = tx.objectStore('documents');
    final previous = await store.getObject(id);
    final record = previous == null
        ? <String, dynamic>{'content': '', 'metadata': <String, dynamic>{}}
        : Map<String, dynamic>.from(previous as Map);
    record['metadata'] = Map<String, dynamic>.from(record['metadata'] as Map);
    change(record);
    await store.put(record, id);
    await tx.completed;
  }

  @override
  Future<Map<String, dynamic>?> readDocument(String id) => _read(id);

  @override
  Future<bool> applyRemote(
      String id, String content, Map<String, dynamic> metadata,
      {String? expectedOperationId}) async {
    var applied = false;
    await _update(id, (record) {
      final previous = record['metadata'] as Map<String, dynamic>;
      if (!StorageService._canApplyRemote(
          previous, metadata, expectedOperationId)) {
        return;
      }
      record['content'] = content;
      record['metadata'] = {...previous, ...metadata, 'pendingSync': null};
      applied = true;
    });
    return applied;
  }

  @override
  Future<void> saveDocument(
          String id, String content, Map<String, dynamic> metadata) =>
      _update(id, (record) {
        record['content'] = content;
        record['metadata'] = {...record['metadata'] as Map, ...metadata};
      });

  @override
  Future<void> updateMetadata(
          String id, void Function(Map<String, dynamic>) update) =>
      _update(
          id, (record) => update(record['metadata'] as Map<String, dynamic>));

  @override
  Future<void> writeContent(String id, String content) =>
      _update(id, (record) => record['content'] = content);

  @override
  Future<String> readContent(String id) async =>
      (await _read(id))?['content'] as String? ?? '';

  @override
  Future<Map<String, dynamic>?> getMetadata(String id) async {
    final record = await _read(id);
    return record == null
        ? null
        : Map<String, dynamic>.from(record['metadata'] as Map);
  }

  @override
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata) =>
      _update(id, (record) => record['metadata'] = metadata);

  @override
  Future<void> deleteContent(String id) async {
    final db = await _database;
    final tx = db.transaction('documents', idbModeReadWrite);
    await tx.objectStore('documents').delete(id);
    await tx.completed;
  }

  @override
  Future<List<String>> getAllFileIds() async {
    final db = await _database;
    final tx = db.transaction('documents', idbModeReadOnly);
    final keys = await tx.objectStore('documents').getAllKeys();
    await tx.completed;
    return keys.cast<String>();
  }

  Future<void> close() async => (await _database).close();
}
