import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/widgets/lyric_text_field.dart';

void main() {
  for (final trailingLine in ['', '\nLyrics', '\n## Chorus\nLyrics']) {
    testWidgets(
        'spaces at the end of a heading advance the caret before typing a letter: $trailingLine',
        (tester) async {
      final controller =
          LyricTextEditingController(text: '## Verse 2$trailingLine');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
        width: 500,
        child: LyricTextField(
            controller: controller,
            style:
                const TextStyle(fontSize: 18, height: 1.6, letterSpacing: 0.2)),
      ))));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      var previousX =
          editable.getLocalRectForCaret(const TextPosition(offset: 10)).left;
      for (var count = 1; count <= 4; count++) {
        final heading = '## Verse 2${' ' * count}';
        controller.value = TextEditingValue(
            text: '$heading$trailingLine',
            selection: TextSelection.collapsed(offset: heading.length));
        await tester.pump();
        final x =
            editable.getLocalRectForCaret(controller.selection.extent).left;
        expect(x, greaterThan(previousX + 1),
            reason: 'Space $count did not advance the caret');
        previousX = x;
      }
      const heading = '## Verse 2    x';
      controller.value = TextEditingValue(
          text: '$heading$trailingLine',
          selection: TextSelection.collapsed(offset: heading.length));
      await tester.pump();
      final beforeLetter =
          editable.getLocalRectForCaret(const TextPosition(offset: 14)).left;
      expect(beforeLetter, closeTo(previousX, 0.01),
          reason: 'Existing spaces moved when a letter was typed');
    });
  }

  testWidgets('spaces before a heading label advance immediately',
      (tester) async {
    final controller = LyricTextEditingController(text: '## Verse');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 500,
      child: LyricTextField(
          controller: controller,
          style:
              const TextStyle(fontSize: 18, height: 1.6, letterSpacing: 0.2)),
    ))));
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    var previousX =
        editable.getLocalRectForCaret(const TextPosition(offset: 3)).left;
    for (var count = 1; count <= 4; count++) {
      controller.value = TextEditingValue(
          text: '## ${' ' * count}Verse',
          selection: TextSelection.collapsed(offset: 3 + count));
      await tester.pump();
      final x =
          editable.getLocalRectForCaret(TextPosition(offset: 3 + count)).left;
      expect(x, greaterThan(previousX + 1),
          reason: 'Leading space $count was hidden');
      previousX = x;
    }
    controller.value = const TextEditingValue(
        text: '##     xVerse', selection: TextSelection.collapsed(offset: 8));
    await tester.pump();
    final beforeLetter =
        editable.getLocalRectForCaret(const TextPosition(offset: 7)).left;
    expect(beforeLetter, closeTo(previousX, 0.01));
  });
}
