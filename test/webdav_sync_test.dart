import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as dav;
import 'package:flowrite/models/writing_file.dart';
import 'package:flowrite/services/backends/webdav_sync_backend.dart';
import 'package:flowrite/services/storage_service.dart';
import 'package:flowrite/services/sync_queue_service.dart';
import 'package:flowrite/services/webdav_config_service.dart';

class Config extends WebDavConfigService {
  @override
  Future<WebDavConfig?> getConfig() async => const WebDavConfig(
      serverUrl: 'https://local.test/dav/',
      username: 'writer',
      appPassword: 'test-only');
}

class DavClient implements dav.Client {
  final List<dav.File> entries;
  DavClient([this.entries = const []]);
  @override
  Future<List<dav.File>> readDir(String path, [CancelToken? token]) async =>
      entries;

  @override
  Future<void> ping([CancelToken? token]) async {}
  @override
  Future<void> mkdirAll(String path, [CancelToken? token]) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RemoteServer implements HttpClientAdapter {
  final records = <String, String>{};
  final versions = <String, int>{};
  Future<void> Function()? beforePut;
  Future<void> Function(String)? beforeGet;
  bool concurrentWrite = false;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? data,
      Future<void>? cancel) async {
    requests.add(options);
    final id = Uri.decodeComponent(
        options.uri.pathSegments.last.replaceFirst('.json', ''));
    if (options.method == 'GET') {
      await beforeGet?.call(id);
      expect(options.headers['Cache-Control'], 'no-cache');
      return ResponseBody.fromString(
          records[id] ?? '', records.containsKey(id) ? 200 : 404,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            'etag': ['"${versions[id]}"']
          });
    }
    if (options.method == 'PUT') {
      await beforePut?.call();
      if (concurrentWrite) return ResponseBody.fromString('', 412);
      if (records.containsKey(id)) {
        expect(options.headers['If-Match'], '"${versions[id]}"');
      } else {
        expect(options.headers['If-None-Match'], '*');
      }
      records[id] = options.data as String;
      versions[id] = (versions[id] ?? 0) + 1;
      return ResponseBody.fromString('', 201);
    }
    throw StateError('Unexpected method ${options.method}');
  }

  @override
  void close({bool force = false}) {}
  void seed(WritingFile file) {
    records[file.id] = file.snapshot;
    versions[file.id] = 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late IndexedDbStorageService storage;
  late RemoteServer server;
  late WebDavSyncBackend backend;
  var index = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = IndexedDbStorageService(
        factory: idbFactoryMemory, databaseName: 'dav-${index++}');
    StorageService.overrideFactory = () => storage;
    server = RemoteServer();
    backend = WebDavSyncBackend(
        configService: Config(),
        http: Dio()..httpClientAdapter = server,
        clientFactory: (_) => DavClient());
  });
  tearDown(() async {
    backend.dispose();
    StorageService.overrideFactory = null;
    await storage.close();
  });

  test('first upload creates remote record and acknowledges local operation',
      () async {
    await WritingFile(id: 'song', name: 'Song').writeContent('Lyrics');
    await backend.processSyncQueue();
    expect(jsonDecode(server.records['song']!)['content'], 'Lyrics');
    expect(await SyncQueueService().getQueue(), isEmpty);
  });
  test('newer local conflict wins even though both versions have the same ID',
      () async {
    server.seed(WritingFile(
        id: 'song',
        name: 'Song',
        content: 'Old',
        lastModified: DateTime.utc(2026, 1, 1)));
    await WritingFile(id: 'song', name: 'Song').writeContent('New');
    await backend.processSyncQueue();
    expect(jsonDecode(server.records['song']!)['content'], 'New');
    expect(
        (await storage.getAllFileIds()).where((id) => id.contains('_backup_')),
        hasLength(1));
  });
  test('remote tombstone removes stale local copy and keeps a conflict backup',
      () async {
    await WritingFile(id: 'song', name: 'Song').writeContent('Offline lyrics');
    server.seed(WritingFile(
        id: 'song',
        name: 'Song',
        isDeleted: true,
        content: '',
        lastModified: DateTime.utc(2026, 1, 1)));
    await backend.processSyncQueue();
    expect((await storage.getMetadata('song'))!['deleted'], isTrue);
    expect(
        (await storage.getAllFileIds()).where((id) => id.contains('_backup_')),
        hasLength(1));
  });
  test('deletion is uploaded as a tombstone', () async {
    final file = WritingFile(id: 'song', name: 'Song');
    await file.writeContent('Lyrics');
    await backend.processSyncQueue();
    await file.delete();
    await backend.processSyncQueue();
    expect(jsonDecode(server.records['song']!)['deleted'], isTrue);
    expect(await SyncQueueService().getQueue(), isEmpty);
  });
  test('concurrent remote modification leaves local edit pending', () async {
    await WritingFile(id: 'song', name: 'Song').writeContent('Lyrics');
    server.concurrentWrite = true;
    await backend.processSyncQueue();
    expect((await SyncQueueService().getQueue()).single.retryCount, 1);
    expect(await storage.readContent('song'), 'Lyrics');
  });
  test('edit made during an upload is retained for the next sync', () async {
    final file = WritingFile(id: 'song', name: 'Song');
    await file.writeContent('First');
    server.beforePut = () async {
      server.beforePut = null;
      await file.writeContent('Second');
    };
    await backend.processSyncQueue();
    expect(jsonDecode(server.records['song']!)['content'], 'First');
    expect(await storage.readContent('song'), 'Second');
    expect(await SyncQueueService().getQueue(), hasLength(1));
    await backend.processSyncQueue();
    expect(jsonDecode(server.records['song']!)['content'], 'Second');
    expect(await SyncQueueService().getQueue(), isEmpty);
  });
  test('remote downloads yield progress and skip a malformed record', () async {
    backend.dispose();
    backend = WebDavSyncBackend(
        configService: Config(),
        http: Dio()..httpClientAdapter = server,
        clientFactory: (_) => DavClient(['one', 'bad', 'two']
            .map((id) => dav.File(name: '$id.json', isDir: false))
            .toList()));
    server.seed(WritingFile(id: 'one', name: 'First', content: 'One'));
    server.seed(WritingFile(id: 'two', name: 'Second', content: 'Two'));
    server.records['bad'] = 'invalid json';
    final waiting = Completer<void>();
    final first = Completer<void>();
    server.beforeGet = (id) async {
      if (id == 'two') await waiting.future;
    };
    final received = <String>[];
    final done = Completer<void>();
    final subscription = backend.getFilesStream().listen((batch) {
      received.addAll(batch.map((file) => file.id));
      if (!first.isCompleted) first.complete();
    }, onDone: done.complete, onError: done.completeError);
    await first.future;
    expect(received, ['one']);
    waiting.complete();
    await done.future;
    expect(received, ['one', 'two']);
    await subscription.cancel();
  });
}
