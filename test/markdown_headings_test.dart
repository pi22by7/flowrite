import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/models/lyric_document.dart';
import 'package:flowrite/utils/markdown_headings.dart';
import 'package:flowrite/widgets/lyric_chord_layer.dart';
import 'package:flowrite/widgets/lyric_text_field.dart';

void main() {
  test(
      'Markdown headings support six levels without coloring section names as lyrics',
      () {
    const source =
        '# Intro\n## Verse 1\n### Chorus\n#### Bridge\n##### Outro\n###### Coda\nC# is a chord\n#hashtag';
    final lyricLines = <String>[];
    final span = buildLyricMarkdownSpan(source, const TextStyle(fontSize: 18),
        lyricLineBuilder: (line, style) {
      lyricLines.add(line);
      return [TextSpan(text: line, style: style.copyWith(color: Colors.blue))];
    });
    expect(span.toPlainText(), source);
    expect(lyricLines, ['C# is a chord', '#hashtag']);
    final headings = span.children!
        .whereType<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.w700);
    expect(headings.length, 6);
    expect(isMarkdownHeading('####### Too many hashes'), isFalse);
    expect(isMarkdownHeading('    ## Indented text'), isFalse);
    expect(isMarkdownHeading('   ## Verse'), isTrue);
  });

  testWidgets('heading names remain editable with hidden markers',
      (tester) async {
    final controller = LyricTextEditingController(text: '## Chorus');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LyricTextField(
      controller: controller,
      style: const TextStyle(fontSize: 18, height: 1.6),
    ))));
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final caret = editable.getLocalRectForCaret(const TextPosition(offset: 3));
    await tester.tapAt(editable.localToGlobal(caret.center));
    await tester.pump();
    expect(controller.selection.baseOffset, greaterThanOrEqualTo(3));
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
    tester.testTextInput.enterText('## Chorus 2');
    await tester.pump();
    expect(controller.text, '## Chorus 2');
    expect(isMarkdownHeading(controller.text), isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
      'inserting a section preserves lyrics, moves their chord, and survives reopening',
      () {
    const document =
        LyricDocument('First lyric\nSecond lyric', [LyricChord(12, 18, 'C')]);
    const current = TextEditingValue(
        text: 'First lyric\nSecond lyric',
        selection: TextSelection.collapsed(offset: 15));
    final inserted = insertSectionHeading(current, 'Chorus');
    expect(inserted.text, 'First lyric\n## Chorus\nSecond lyric');
    expect(inserted.selection.baseOffset, 22);
    final changed = document.edit(inserted.text);
    expect(changed.chords.single.start, 22);
    final reopened = LyricDocument.decode(changed.encode());
    expect(reopened.text, inserted.text);
    expect(reopened.chords.single.start, 22);
  });

  test(
      'format and remove affect only the current line and handle an empty song',
      () {
    const initial = TextEditingValue(
        text: 'Verse 1\nLyrics', selection: TextSelection.collapsed(offset: 2));
    final heading = formatSectionHeading(initial);
    expect(heading.text, '## Verse 1\nLyrics');
    expect(formatSectionHeading(heading).text, heading.text);
    expect(formatSectionHeading(heading, remove: true).text, initial.text);
    final empty = formatSectionHeading(TextEditingValue.empty);
    expect(empty.text, '## Section');
    expect(empty.selection.textInside(empty.text), 'Section');
    expect(insertSectionHeading(TextEditingValue.empty, 'Verse').text,
        '## Verse\n');
  });

  testWidgets(
      'wrapped headings share layout with chord anchors and keep Markdown editable',
      (tester) async {
    const text =
        '## A long chorus heading that wraps across lines\nHere are the lyrics';
    final anchor = text.indexOf('the lyrics');
    final controller = LyricTextEditingController(text: text);
    addTearDown(controller.dispose);
    const style = TextStyle(fontSize: 18, height: 1.6, color: Colors.black);
    for (final scale in [1.0, 1.5]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: 240,
                child: LyricChordLayer(
                    document: LyricDocument(
                        text, [LyricChord(anchor, anchor + 3, 'G')]),
                    style: style,
                    onEdit: (_) {},
                    onMove: (_, __) {},
                    child: LyricTextField(
                        controller: controller,
                        style: style,
                        hasChords: true)))),
      ))));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final native = editable.text!;
      expect(native.toPlainText(), text);
      var bold = false;
      native.visitChildren((span) {
        if (span is TextSpan &&
            span.text?.startsWith('A long chorus') == true) {
          bold = span.style?.fontWeight == FontWeight.w700;
        }
        return true;
      });
      expect(bold, isTrue);
      final sourceStart =
          editable.getLocalRectForCaret(const TextPosition(offset: 0));
      final labelStart =
          editable.getLocalRectForCaret(const TextPosition(offset: 3));
      expect(sourceStart.left, closeTo(labelStart.left, 0.01),
          reason: 'Markdown markers must not occupy visual space');
      expect(labelStart.left, closeTo(0, 0.01));
      final caret = editable.getLocalRectForCaret(TextPosition(offset: anchor));
      final position = editable.localToGlobal(caret.topLeft);
      final chord = tester.getRect(find.ancestor(
          of: find.text('G'), matching: find.byType(Draggable<LyricChord>)));
      expect(chord.left, closeTo(position.dx, 0.01));
      expect(chord.bottom, lessThan(position.dy));
      expect(tester.takeException(), isNull);
    }
  });
}
