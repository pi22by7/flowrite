import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/models/lyric_document.dart';
import 'package:flowrite/widgets/lyric_text_field.dart';
import 'package:flowrite/widgets/lyric_chord_layer.dart';

void main() {
  test(
      'inserting identical words before a chord keeps the original word anchored',
      () {
    const document = LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    final changed = document.edit('hello world world',
        selectionStart: 6, selectionEnd: 6, caretOffset: 12);
    expect(changed.chords.single.start, 12);
    expect(changed.chords.single.end, 17);
    expect(changed.text.substring(changed.chords.single.start), 'world');
  });

  test(
      'every insertion point before a lyric shifts its anchor, including repeated letters and newlines',
      () {
    const document = LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    for (var cursor = 0; cursor <= 6; cursor++) {
      for (final insertion in ['w', 'world ', 'hello ', ' ', '\n', 'world\n']) {
        final changed = document.edit(
            document.text.replaceRange(cursor, cursor, insertion),
            selectionStart: cursor,
            selectionEnd: cursor,
            caretOffset: cursor + insertion.length);
        expect(changed.chords.single.start, 6 + insertion.length,
            reason: 'insertion "$insertion" at $cursor');
        expect(
            changed.text.substring(
                changed.chords.single.start, changed.chords.single.end),
            'world');
      }
    }
  });

  test(
      'replacing selected lyrics before a chord preserves it despite shared letters',
      () {
    const document = LyricDocument('Test of of song', [LyricChord(8, 10, 'C')]);
    final changed = document.edit('Test often of song',
        selectionStart: 5, selectionEnd: 7, caretOffset: 10);
    expect(changed.chords.single.start, 11);
    expect(changed.text.substring(11, 13), 'of');
  });

  test(
      'backspace and forward delete distinguish repeated text around the caret',
      () {
    const document = LyricDocument('aa world', [LyricChord(3, 8, 'C')]);
    final backward = document.edit('a world',
        selectionStart: 1, selectionEnd: 1, caretOffset: 0);
    final forward = document.edit('a world',
        selectionStart: 0, selectionEnd: 0, caretOffset: 0);
    expect(backward.chords.single.start, 2);
    expect(forward.chords.single.start, 2);
  });

  test(
      'typing, pasting and deleting before the word uses the controller edit history',
      () {
    var document = const LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    final controller = LyricTextEditingController(text: document.text);
    addTearDown(controller.dispose);
    controller
        .addListener(() => document = controller.updateDocument(document));
    controller.selection = const TextSelection.collapsed(offset: 6);
    var inserted = '';
    for (final char in 'world wonderful '.split('')) {
      final cursor = controller.selection.extentOffset;
      controller.value = controller.value
          .replaced(TextRange(start: cursor, end: cursor), char);
      inserted += char;
      expect(document.chords.single.start, 6 + inserted.length,
          reason: 'typed "$inserted"');
      expect(
          document.text.substring(
              document.chords.single.start, document.chords.single.end),
          'world');
    }
    controller.selection =
        TextSelection(baseOffset: 6, extentOffset: 6 + inserted.length);
    controller.value = controller.value
        .replaced(TextRange(start: 6, end: 6 + inserted.length), '');
    expect(document.text, 'hello world');
    expect(document.chords.single.start, 6);
    final restored = LyricDocument.decode(document.encode());
    expect(restored.chords.single.start, 6);
    expect(restored.chords.single.label, 'C');
  });

  test('edits away from the old caret fall back safely for autocorrection', () {
    const document = LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    final changed = document.edit('hello word',
        selectionStart: 11, selectionEnd: 11, caretOffset: 10);
    expect(changed.chords.single.start, 6);
    expect(changed.chords.single.end, 10);
  });

  testWidgets(
      'native typing before an anchored word preserves its chord through wrapping',
      (tester) async {
    var document = const LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    final controller = LyricTextEditingController(text: document.text);
    addTearDown(controller.dispose);
    late StateSetter update;
    controller.addListener(() {
      if (document.text != controller.text) {
        update(() => document = controller.updateDocument(document));
      }
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        const style = TextStyle(fontSize: 18, height: 1.6, color: Colors.black);
        return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: 180,
                child: LyricChordLayer(
                    document: document,
                    style: style,
                    onEdit: (_) {},
                    onMove: (_, __) {},
                    child: LyricTextField(
                        controller: controller,
                        style: style,
                        hasChords: true))));
      },
    ))));
    await tester.showKeyboard(find.byType(TextField));
    controller.selection = const TextSelection.collapsed(offset: 6);
    for (final character in 'world new\n'.split('')) {
      final cursor = controller.selection.extentOffset;
      tester.testTextInput.updateEditingValue(controller.value
          .replaced(TextRange(start: cursor, end: cursor), character));
      await tester.pump();
      expect(document.chords.single.start, document.text.lastIndexOf('world'));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final caret = editable.localToGlobal(editable
          .getLocalRectForCaret(
              TextPosition(offset: document.chords.single.start))
          .topLeft);
      final chord = tester.getRect(find.ancestor(
          of: find.text('C'), matching: find.byType(Draggable<LyricChord>)));
      expect(chord.left, closeTo(caret.dx, 0.01));
      expect(chord.bottom, lessThan(caret.dy));
    }
    expect(tester.takeException(), isNull);
  });
}
