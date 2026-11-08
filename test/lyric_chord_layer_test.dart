import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/models/lyric_document.dart';
import 'package:flowrite/widgets/lyric_chord_layer.dart';
import 'package:flowrite/widgets/lyric_text_field.dart';

void main() {
  testWidgets('chord can be edited and dragged onto a different lyric',
      (tester) async {
    const style = TextStyle(fontSize: 20, height: 3);
    const chord = LyricChord(0, 5, 'Am');
    final controller = LyricTextEditingController(text: 'hello world');
    addTearDown(controller.dispose);
    LyricChord? edited;
    int? moved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 300,
      child: LyricChordLayer(
        document: const LyricDocument('hello world', [chord]),
        style: style,
        onEdit: (value) => edited = value,
        onMove: (_, offset) => moved = offset,
        child: LyricTextField(
            controller: controller, style: style, hasChords: true),
      ),
    ))));
    await tester.tap(find.text('Am'));
    expect(edited, chord);
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final destination = editable.localToGlobal(
        editable.getLocalRectForCaret(const TextPosition(offset: 7)).center);
    final start = tester.getCenter(find.text('Am'));
    await tester.dragFrom(start, destination - start);
    await tester.pumpAndSettle();
    expect(moved, 6);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dragging uses wrapped lines and enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const text = 'one two three four five six seven';
    const style = TextStyle(fontSize: 20, height: 3);
    const chord = LyricChord(0, 3, 'G');
    final controller = LyricTextEditingController(text: text);
    addTearDown(controller.dispose);
    int? moved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: LyricChordLayer(
              document: const LyricDocument(text, [chord]),
              style: style,
              onEdit: (_) {},
              onMove: (_, offset) => moved = offset,
              child: LyricTextField(
                  controller: controller, style: style, hasChords: true),
            ),
          )),
    ))));
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final destination = editable.localToGlobal(
        editable.getLocalRectForCaret(const TextPosition(offset: 29)).center);
    final start = tester.getCenter(find.text('G'));
    await tester.dragFrom(start, destination - start);
    await tester.pumpAndSettle();
    expect(moved, text.indexOf('seven'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('lyric clicks below a chord reach the text field on every line',
      (tester) async {
    const style = TextStyle(fontSize: 20, height: 3);
    final controller = LyricTextEditingController(text: 'hello\nworld\nagain');
    addTearDown(controller.dispose);
    var edits = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
          width: 300,
          child: LyricChordLayer(
            document:
                LyricDocument(controller.text, const [LyricChord(0, 5, 'C')]),
            style: style,
            onEdit: (_) => edits++,
            onMove: (_, __) {},
            child: LyricTextField(
                controller: controller, style: style, hasChords: true),
          )),
    ))));
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    for (var line = 0; line < 3; line++) {
      final caret =
          editable.getLocalRectForCaret(TextPosition(offset: line * 6 + 1));
      await tester.tapAt(editable.localToGlobal(caret.center));
      await tester.pump();
      expect(edits, 0);
      expect(controller.selection.baseOffset,
          inInclusiveRange(line * 6, line * 6 + 5));
    }
  });

  testWidgets(
      'inline chord editing saves on blur and Enter and cancels on Escape',
      (tester) async {
    const chord = LyricChord(0, 5, 'Am');
    LyricChord? editing;
    String? saved;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return Column(children: [
          SizedBox(
              width: 300,
              child: LyricChordLayer(
                document: const LyricDocument('hello', [chord]),
                editingChord: editing,
                onEdit: (c) => setState(() => editing = c),
                onCommit: (_, label) => setState(() {
                  saved = label;
                  editing = null;
                }),
                onCancel: () => setState(() => editing = null),
                onMove: (_, __) {},
                style: const TextStyle(fontSize: 20, height: 3),
                child: const SizedBox(height: 60, width: 300),
              )),
          const TextField(key: ValueKey('other-input')),
        ]);
      },
    ))));
    final input = find.byKey(const ValueKey('inline-chord-input'));
    await tester.tap(find.text('Am'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(input, 'D/F#');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(saved, 'D/F#');
    expect(input, findsNothing);

    update(() => editing = chord);
    await tester.pump();
    await tester.enterText(input, 'G7');
    await tester.tap(find.byKey(const ValueKey('other-input')));
    await tester.pump();
    expect(saved, 'G7');
    expect(input, findsNothing);

    update(() => editing = chord);
    await tester.pump();
    await tester.enterText(input, 'B');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(saved, 'G7');
    expect(input, findsNothing);
  });
}
