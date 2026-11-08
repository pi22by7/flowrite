import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowrite/models/writing_file.dart';
import 'package:flowrite/services/storage_service.dart';
import 'package:flowrite/services/sync_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FileSystemStorageService storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flowrite-native-test-');
    SharedPreferences.setMockInitialValues({'customSavePath': directory.path});
    storage = FileSystemStorageService();
    StorageService.overrideFactory = () => storage;
  });
  tearDown(() async {
    StorageService.overrideFactory = null;
    await directory.delete(recursive: true);
  });

  test(
      'native document, title and outbox survive removal of preference metadata',
      () async {
    final file = WritingFile(id: 'song', name: 'Title');
    await file.writeContent('Native lyrics 🎶');
    SharedPreferences.setMockInitialValues({'customSavePath': directory.path});
    storage = FileSystemStorageService();
    expect(await storage.readContent('song'), 'Native lyrics 🎶');
    expect((await storage.getMetadata('song'))!['name'], 'Title');
    expect(await SyncQueueService().getQueue(), hasLength(1));
    expect(await File('${directory.path}/song.flowrite.json').exists(), isTrue);
  });

  test('legacy text and title are read and upgraded on first edit', () async {
    await File('${directory.path}/song.text').writeAsString('Legacy');
    SharedPreferences.setMockInitialValues({
      'customSavePath': directory.path,
      'file_metadata_song': jsonEncode({
        'id': 'song',
        'name': 'Old title',
        'lastModified': '2026-01-01T00:00:00Z'
      })
    });
    expect(await storage.readContent('song'), 'Legacy');
    await WritingFile(id: 'song', name: 'Old title').writeContent('Upgraded');
    expect(await storage.getAllFileIds(), ['song']);
    expect(await storage.readContent('song'), 'Upgraded');
  });

  test('location migration includes document metadata and pending deletion',
      () async {
    final file = WritingFile(id: 'song', name: 'Title');
    await file.writeContent('Lyrics');
    await file.delete();
    final destination = '${directory.path}/moved';
    final result = await storage.migrateStorageLocation(destination);
    expect(result.success, isTrue);
    expect(result.migratedCount, 1);
    expect((await storage.getMetadata('song'))!['deleted'], isTrue);
    expect(await SyncQueueService().getQueue(), hasLength(1));
    expect(await File('$destination/song.flowrite.json').exists(), isTrue);
    expect(
        await File('${directory.path}/song.flowrite.json').exists(), isFalse);
  });

  test(
      'corrupt native record is reported instead of silently loading empty text',
      () async {
    await File('${directory.path}/song.flowrite.json').writeAsString('corrupt');
    expect(storage.readContent('song'), throwsFormatException);
  });
}
