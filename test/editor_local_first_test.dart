import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowrite/models/writing_file.dart';
import 'package:flowrite/providers/settings_provider.dart';
import 'package:flowrite/providers/sync_provider.dart';
import 'package:flowrite/screens/editor_screen.dart';
import 'package:flowrite/services/storage_service.dart';
import 'package:flowrite/services/sync_queue_service.dart';
import 'package:flowrite/widgets/lyric_text_field.dart';

class EditorStorage extends StorageService {
  bool failWrites = false;
  final records = <String, Map<String, dynamic>>{};
  @override
  Future<void> saveDocument(
      String id, String content, Map<String, dynamic> metadata) async {
    if (failWrites) throw StateError('Test storage write failure');
    records[id] = {
      'content': content,
      'metadata': {...?records[id]?['metadata'] as Map?, ...metadata}
    };
  }

  @override
  Future<String> readContent(String id) async =>
      records[id]?['content'] as String? ?? '';
  @override
  Future<Map<String, dynamic>?> getMetadata(String id) async =>
      records[id] == null
          ? null
          : Map<String, dynamic>.from(records[id]!['metadata'] as Map);
  @override
  Future<void> saveMetadata(String id, Map<String, dynamic> metadata) async {
    records.putIfAbsent(id, () => {})['metadata'] = metadata;
  }

  @override
  Future<void> writeContent(String id, String content) async {
    records.putIfAbsent(id, () => {})['content'] = content;
  }

  @override
  Future<void> deleteContent(String id) async {
    records.remove(id);
  }

  @override
  Future<List<String>> getAllFileIds() async => records.keys.toList();
}

void main() {
  late EditorStorage storage;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = EditorStorage();
    StorageService.overrideFactory = () => storage;
  });
  tearDown(() async {
    StorageService.overrideFactory = null;
  });

  Future<void> openEditor(WidgetTester tester) async {
    final file = WritingFile(
        id: 'song',
        name: 'Song',
        content: '# Song\nOriginal lyrics',
        lastModified: DateTime.utc(2026, 1, 1));
    await tester.runAsync(() => file.saveRemote());
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => SyncProvider()),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => EditorScreen(file: file))),
                        child: const Text('Open song')))))));
    await tester.tap(find.text('Open song'));
    await tester.pump();
    // The editor animates continuously, so pumpAndSettle is not appropriate.
    for (var attempt = 0;
        attempt < 20 && find.byType(LyricTextField).evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(LyricTextField), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'opening a downloaded song does not rewrite it or queue an upload',
      (tester) async {
    await openEditor(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(await tester.runAsync(() => SyncQueueService().getQueue()), isEmpty);
    final meta = await tester.runAsync(() => storage.getMetadata('song'));
    expect(meta!['lastModified'], DateTime.utc(2026, 1, 1).toIso8601String());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('backgrounding flushes edits before the autosave delay',
      (tester) async {
    await openEditor(tester);
    final body = find.descendant(
        of: find.byType(LyricTextField), matching: find.byType(EditableText));
    await tester.enterText(body, 'Edited before switching apps');
    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(await tester.runAsync(() => storage.readContent('song')),
        contains('Edited before switching apps'));
    expect(await tester.runAsync(() => SyncQueueService().getQueue()),
        hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('back navigation waits for local changes to be saved',
      (tester) async {
    await openEditor(tester);
    final body = find.descendant(
        of: find.byType(LyricTextField), matching: find.byType(EditableText));
    await tester.enterText(body, 'Saved before leaving');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EditorScreen), findsNothing);
    expect(await storage.readContent('song'), contains('Saved before leaving'));
  });

  testWidgets('failed local save keeps the editor open on back navigation',
      (tester) async {
    await openEditor(tester);
    final body = find.descendant(
        of: find.byType(LyricTextField), matching: find.byType(EditableText));
    await tester.enterText(body, 'Unsaved edit');
    storage.failWrites = true;
    await tester.pump();
    await tester.runAsync(() async {
      await tester.binding.handlePopRoute();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.text('Could not save locally. Please save before leaving.'),
        findsWidgets);
    expect(await storage.readContent('song'), contains('Original lyrics'));
    await tester.pumpWidget(const SizedBox());
  });
}
