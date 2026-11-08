import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowrite/models/lyric_document.dart';
import 'package:flowrite/providers/settings_provider.dart';
import 'package:flowrite/widgets/chord_visibility_toggle.dart';
import 'package:flowrite/widgets/lyric_chord_layer.dart';
import 'package:flowrite/widgets/lyric_text_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'chords are shown by default and visibility persists independently of line spacing',
      () async {
    SharedPreferences.setMockInitialValues({'lineHeight': 1.2});
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(settings.showChords, isTrue);
    final saving = settings.setShowChords(false);
    expect(settings.showChords, isFalse);
    await saving;
    final restored = SettingsProvider();
    addTearDown(restored.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(restored.showChords, isFalse);
    expect(restored.lineHeight, 1.2);
    await restored.setShowChords(true);
    expect(
        (await SharedPreferences.getInstance()).getBool('showChords'), isTrue);
  });

  testWidgets(
      'toggle hides chords and extra spacing, preserves anchors during lyric edits, and restores them',
      (tester) async {
    const style = TextStyle(fontSize: 18, height: 1.6, color: Colors.black);
    var document = const LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    final initialContent = document.encode();
    final controller = LyricTextEditingController(text: document.text);
    addTearDown(controller.dispose);
    var shown = true;
    late StateSetter update;
    controller.addListener(() {
      if (controller.text != document.text) {
        update(() => document = document.edit(controller.text));
      }
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return Column(children: [
          ChordVisibilityToggle(
              value: shown,
              onChanged: (value) => setState(() => shown = value)),
          SizedBox(
              width: 300,
              child: LyricChordLayer(
                visible: shown,
                document: document,
                style: style,
                onEdit: (_) {},
                onMove: (_, __) {},
                child: LyricTextField(
                    controller: controller, style: style, hasChords: shown),
              )),
        ]);
      },
    ))));
    final field = find.byType(LyricTextField);
    final expandedHeight = tester.getSize(field).height;
    expect(find.text('C'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsNothing);
    expect(find.byType(Draggable<LyricChord>), findsNothing);
    expect(tester.getSize(field).height, lessThan(expandedHeight));
    expect(document.encode(), initialContent);

    await tester.enterText(find.byType(TextField), 'new hello world');
    await tester.pump();
    expect(document.chords.single.start, 10);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
    expect(controller.text, 'new hello world');
    final saved = LyricDocument.decode(document.encode());
    expect(saved.chords.single.start, 10);
    expect(saved.chords.single.label, 'C');
    expect(tester.takeException(), isNull);
  });
}
