import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowrite/models/writing_file.dart';
import 'package:flowrite/models/sync_operation.dart';
import 'package:flowrite/services/storage_service.dart';
import 'package:flowrite/services/sync_queue_service.dart';
import 'package:flowrite/providers/sync_provider.dart';
import 'package:flowrite/providers/settings_provider.dart';
import 'package:flowrite/services/webdav_config_service.dart';

class MemoryWebDavConfigService extends WebDavConfigService {
  WebDavConfig? value;
  @override
  Future<WebDavConfig?> getConfig() async => value;
  @override
  Future<void> saveConfig(WebDavConfig config) async {
    validate(config);
    value = config;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late IndexedDbStorageService storage;
  var counter = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = IndexedDbStorageService(
        factory: idbFactoryMemory, databaseName: 'local-first-${counter++}');
    StorageService.overrideFactory = () => storage;
  });
  tearDown(() async {
    StorageService.overrideFactory = null;
    await storage.close();
  });

  test(
      'legacy documents and deletion queue migrate once, retaining original data',
      () async {
    final deletion =
        SyncQueueService.newOperation('removed', SyncOperationType.delete);
    SharedPreferences.setMockInitialValues({
      'file_content_legacy': 'Old lyrics 🎵',
      'file_metadata_legacy': jsonEncode({
        'id': 'legacy',
        'name': 'Old title',
        'lastModified': '2026-01-01T00:00:00Z'
      }),
      'sync_queue': [jsonEncode(deletion.toJson())],
    });
    expect(await storage.readContent('legacy'), 'Old lyrics 🎵');
    expect((await storage.getMetadata('removed'))!['deleted'], isTrue);
    expect((await SyncQueueService().getQueue()).single.id, deletion.id);
    final file = WritingFile(id: 'legacy', name: 'New title');
    await file.writeContent('Revised');
    await storage.close();
    storage = IndexedDbStorageService(
        factory: idbFactoryMemory, databaseName: storage.databaseName);
    expect(await storage.readContent('legacy'), 'Revised');
    expect(
        (await SharedPreferences.getInstance())
            .getString('file_content_legacy'),
        'Old lyrics 🎵');
  });

  test('save persists content and pending operation together across reopen',
      () async {
    final file = WritingFile(id: 'song', name: 'Song');
    await file.writeContent('Durable lyrics');
    final pending = (await SyncQueueService().getQueue()).single;
    await storage.close();
    storage = IndexedDbStorageService(
        factory: idbFactoryMemory, databaseName: storage.databaseName);
    expect(await storage.readContent('song'), 'Durable lyrics');
    expect((await SyncQueueService().getQueue()).single.id, pending.id);
  });

  test('acknowledging an upload never clears a newer local edit', () async {
    final file = WritingFile(id: 'song', name: 'Song');
    await file.writeContent('First');
    final old = (await SyncQueueService().getQueue()).single;
    await file.writeContent('Second');
    await SyncQueueService().dequeue(old.id);
    expect((await SyncQueueService().getQueue()).single.id, isNot(old.id));
    expect(await storage.readContent('song'), 'Second');
  });

  test('download preserves timestamp and does not create an upload', () async {
    final modified = DateTime.utc(2026, 1, 1);
    final remote = WritingFile(
        id: 'song',
        name: 'Remote',
        content: 'Downloaded',
        lastModified: modified);
    expect(await remote.saveRemote(), isTrue);
    expect((await SyncQueueService().getQueue()), isEmpty);
    expect((await storage.getMetadata('song'))!['lastModified'],
        modified.toIso8601String());
    final local = WritingFile(id: 'song', name: 'Local');
    await local.writeContent('Pending edit');
    expect(await remote.saveRemote(), isFalse);
    expect(await storage.readContent('song'), 'Pending edit');
  });

  test('download cannot replace an edit made while resolving a conflict',
      () async {
    final local = WritingFile(id: 'song', name: 'Song');
    await local.writeContent('First');
    final old = (await SyncQueueService().getQueue()).single;
    await local.writeContent('Second');
    final remote =
        WritingFile(id: 'song', name: 'Remote', content: 'Stale download');
    expect(await remote.saveRemote(expectedOperationId: old.id), isFalse);
    expect(await storage.readContent('song'), 'Second');
  });

  test('tombstone survives reopen and blocks stale remote resurrection',
      () async {
    final file = WritingFile(id: 'song', name: 'Song');
    await file.writeContent('Lyrics');
    await file.delete();
    await SyncQueueService().dequeueFile('song');
    final remote =
        WritingFile(id: 'song', name: 'Stale', content: 'Old lyrics');
    expect(await remote.saveRemote(), isFalse);
    expect((await storage.getMetadata('song'))!['deleted'], isTrue);
  });

  test('simultaneous writes retain each document in the outbox', () async {
    await Future.wait(List.generate(
        20, (i) => WritingFile(id: 's$i', name: '$i').writeContent('$i')));
    expect((await SyncQueueService().getQueue()).length, 20);
  });

  test('local-only provider starts without Supabase and preserves unsent edits',
      () async {
    final file = WritingFile(id: 'song', name: 'Song');
    await file.writeContent('Offline');
    final provider = SyncProvider();
    await provider.ready;
    expect(provider.backendType, SyncBackendType.none);
    expect(provider.isCloudConfigured, isFalse);
    expect(provider.currentUser, isNull);
    await provider.checkPendingSyncs();
    expect((await SyncQueueService().getQueue()).length, 1);
    expect(await provider.activeBackend.isOnline, isFalse);
    provider.dispose();
  });
  test('selecting a server queues already-synced local documents and deletions',
      () async {
    final file = WritingFile(id: 'song', name: 'Song');
    await file.writeContent('Lyrics');
    await SyncQueueService().dequeueFile('song');
    final removed = WritingFile(id: 'removed', name: 'Removed');
    await removed.delete();
    await SyncQueueService().dequeueFile('removed');
    final provider = SyncProvider();
    await provider.ready;
    await provider.switchBackend(SyncBackendType.webdav);
    expect((await SyncQueueService().getQueue()).map((op) => op.fileId).toSet(),
        {'song', 'removed'});
    await provider.switchBackend(SyncBackendType.none);
    expect(await SyncQueueService().getQueue(), hasLength(2));
    provider.dispose();
  });

  test('unconfigured Supabase fails without changing local-only mode',
      () async {
    final provider = SyncProvider();
    await provider.ready;
    await expectLater(
        provider.switchBackend(SyncBackendType.supabase), throwsStateError);
    expect(provider.backendType, SyncBackendType.none);
    provider.dispose();
  });

  test('clean local copy accepts an older tombstone despite clock skew',
      () async {
    await WritingFile(
            id: 'song',
            name: 'Song',
            content: 'Lyrics',
            lastModified: DateTime.utc(2030))
        .saveRemote();
    expect(
        await WritingFile(
                id: 'song',
                name: 'Song',
                isDeleted: true,
                lastModified: DateTime.utc(2026))
            .saveRemote(),
        isTrue);
    expect((await storage.getMetadata('song'))!['deleted'], isTrue);
  });
  test(
      'completed migration ignores damaged retained preferences on later launches',
      () async {
    await WritingFile(id: 'song', name: 'Song').writeContent('Durable');
    await storage.close();
    SharedPreferences.setMockInitialValues({
      'file_content_legacy': 'Old',
      'file_metadata_legacy': 'invalid json',
      'sync_queue': ['invalid json']
    });
    storage = IndexedDbStorageService(
        factory: idbFactoryMemory, databaseName: storage.databaseName);
    expect(await storage.readContent('song'), 'Durable');
  });

  test('legacy deletion remains deleted even when stale content still exists',
      () async {
    final deletion =
        SyncQueueService.newOperation('legacy', SyncOperationType.delete);
    SharedPreferences.setMockInitialValues({
      'file_content_legacy': 'Stale lyrics',
      'sync_queue': [jsonEncode(deletion.toJson())]
    });
    expect((await storage.getMetadata('legacy'))!['deleted'], isTrue);
  });

  test(
      'changing WebDAV servers replaces the backend to invalidate old downloads',
      () async {
    final config = MemoryWebDavConfigService();
    final provider = SyncProvider(webDavConfigService: config);
    await provider.ready;
    await provider.configureWebDav(const WebDavConfig(
        serverUrl: 'https://first.test/dav/',
        username: 'writer',
        appPassword: 'test'));
    final previous = provider.activeBackend;
    await provider.configureWebDav(const WebDavConfig(
        serverUrl: 'https://second.test/dav/',
        username: 'writer',
        appPassword: 'test'));
    expect(provider.activeBackend, isNot(same(previous)));
    expect(config.value!.serverUrl, 'https://second.test/dav/');
    provider.dispose();
  });
}
