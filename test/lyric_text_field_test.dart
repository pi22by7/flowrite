import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/widgets/lyric_text_field.dart';
import 'package:flowrite/widgets/lyric_chord_layer.dart';
import 'package:flowrite/models/lyric_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fonts = {
    'Inter': 'Inter-VariableFont_opsz,wght.ttf',
    'Roboto Mono': 'RobotoMono-VariableFont_wght.ttf',
    'JetBrains Mono': 'JetBrainsMono-VariableFont_wght.ttf',
    'Source Code Pro': 'SourceCodePro-VariableFont_wght.ttf',
    'Merriweather': 'Merriweather-VariableFont_opsz,wdth,wght.ttf',
    'Playfair Display': 'PlayfairDisplay-VariableFont_wght.ttf',
    'Lora': 'Lora-VariableFont_wght.ttf',
    'Fascinate': 'Fascinate-Regular.ttf',
  };
  setUpAll(() async {
    for (final entry in fonts.entries) {
      await (FontLoader(entry.key)
            ..addFont(rootBundle.load('assets/fonts/${entry.value}')))
          .load();
    }
  });

  for (final family in fonts.keys) {
    testWidgets(
        '$family keeps the caret on the letters across typography and rhyme settings',
        (tester) async {
      final controller = LyricTextEditingController(
          text: 'Testing the chords\nTesting the rhyming\n');
      addTearDown(controller.dispose);
      for (final fontSize in [14.0, 24.0]) {
        for (final height in [1.0, 2.0, 3.2, 3.6]) {
          for (final scale in [1.0, 1.5]) {
            Rect? plainCaret;
            for (final colors in [false, true]) {
              final style = lyricLayoutStyle(TextStyle(
                  fontFamily: family,
                  fontSize: fontSize,
                  height: height,
                  letterSpacing: 0.2,
                  color: Colors.black));
              controller.spanBuilder =
                  (_, base) => TextSpan(style: base, children: [
                        TextSpan(
                            text: controller.text.substring(0, 8),
                            style: TextStyle(
                                color: colors ? Colors.blue : base.color)),
                        TextSpan(
                            text: controller.text.substring(8),
                            style: TextStyle(
                                color: colors ? Colors.pink : base.color)),
                      ]);
              await tester.pumpWidget(MaterialApp(
                  home: Scaffold(
                      body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: 290,
                        child: LyricTextField(
                            controller: controller, style: style))),
              ))));
              final editable = tester
                  .state<EditableTextState>(find.byType(EditableText))
                  .renderEditable;
              final paragraph = TextPainter(
                  text: editable.text,
                  textDirection: TextDirection.ltr,
                  textScaler: TextScaler.linear(scale),
                  strutStyle: lyricStrutStyle(style))
                ..layout(maxWidth: lyricParagraphWidth(editable.size.width));
              final natural = TextPainter(
                  text: TextSpan(
                      text: 'M',
                      style: style.copyWith(height: kTextHeightNone)),
                  textDirection: TextDirection.ltr,
                  textScaler: TextScaler.linear(scale))
                ..layout();
              final naturalLine = natural.computeLineMetrics().single;
              final lines = paragraph.computeLineMetrics();
              final reason =
                  '$family size=$fontSize height=$height scale=$scale colors=$colors';
              // Check all visual lines, including wrapping and the empty final line.
              var offset = 0;
              for (final line in lines) {
                final position =
                    paragraph.getPositionForOffset(Offset(1, line.baseline));
                offset = position.offset;
                final caret =
                    editable.getLocalRectForCaret(TextPosition(offset: offset));
                final expectedCenter =
                    line.baseline - naturalLine.ascent + natural.height / 2;
                expect(caret.center.dy, closeTo(expectedCenter, 3),
                    reason: reason);
                expect(caret.height, closeTo(natural.height, 0.01),
                    reason: reason);
              }
              final caret =
                  editable.getLocalRectForCaret(const TextPosition(offset: 3));
              if (colors) {
                expect(caret, plainCaret,
                    reason: 'Rhyme colors changed geometry: $reason');
              } else {
                plainCaret = caret;
              }
              paragraph.dispose();
              natural.dispose();
            }
          }
        }
      }
    });
  }

  for (final family in fonts.keys) {
    testWidgets(
        '$family chords stay above their lyrics across the full breathing-room range',
        (tester) async {
      final controller = LyricTextEditingController(
          text: 'First lyric\nSecond lyric\nThird lyric\n');
      addTearDown(controller.dispose);
      for (final fontSize in [14.0, 24.0]) {
        for (final scale in [1.0, 1.5]) {
          double? previousStride;
          double? firstStride;
          for (final height in [1.0, 1.2, 1.4, 1.6, 1.8, 2.0]) {
            final style = lyricLayoutStyle(TextStyle(
                fontFamily: family,
                fontSize: fontSize,
                height: height,
                color: Colors.black));
            const document =
                LyricDocument('First lyric\nSecond lyric\nThird lyric\n', [
              LyricChord(6, 11, 'G'),
              LyricChord(19, 24, 'C'),
              LyricChord(31, 36, 'D'),
            ]);
            await tester.pumpWidget(MaterialApp(
                home: Scaffold(
                    body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: 500,
                      child: LyricChordLayer(
                          document: document,
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
            final origin = editable.localToGlobal(Offset.zero);
            final scaler = TextScaler.linear(scale);
            final painter = TextPainter(
                text: editable.text,
                textDirection: TextDirection.ltr,
                textScaler: scaler,
                strutStyle:
                    lyricStrutStyle(style, hasChords: true, textScaler: scaler))
              ..layout(maxWidth: lyricParagraphWidth(editable.size.width));
            final lines = painter.computeLineMetrics();
            final font = lyricFontMetrics(style, scaler);
            final reason = '$family size=$fontSize scale=$scale height=$height';
            Rect? previousLabel;
            for (var i = 0; i < 3; i++) {
              final draggable = find.ancestor(
                  of: find.text(['G', 'C', 'D'][i]),
                  matching: find.byType(Draggable<LyricChord>));
              final label = tester.getRect(draggable).shift(-origin);
              final glyphTop = lines[i].baseline - font.ascent;
              final caret = editable.getLocalRectForCaret(
                  TextPosition(offset: document.chords[i].start));
              expect(caret.center.dy, closeTo(glyphTop + font.height / 2, 3),
                  reason: reason);
              expect(label.bottom, closeTo(glyphTop - 6, 0.01), reason: reason);
              expect(label.top + origin.dy, greaterThanOrEqualTo(0),
                  reason: reason);
              if (i > 0) {
                final previousGlyphBottom =
                    lines[i - 1].baseline + font.height - font.ascent;
                expect(
                    label.top, greaterThanOrEqualTo(previousGlyphBottom + 4.9),
                    reason: reason);
              }
              if (previousLabel != null) {
                expect(label.top - previousLabel.top,
                    closeTo(lines[i].baseline - lines[i - 1].baseline, 0.01),
                    reason: reason);
              }
              previousLabel = label;
            }
            final stride = lines[1].baseline - lines[0].baseline;
            if (previousStride != null) {
              // Every step must retain its original effect, allowing the
              // engine's one-pixel rounding of paragraph line metrics.
              expect(stride - previousStride,
                  closeTo(fontSize * scale * 0.2, 1.01),
                  reason: reason);
            }
            firstStride ??= stride;
            if (height == 2.0) {
              expect(stride - firstStride, closeTo(fontSize * scale, 1.01),
                  reason: 'Breathing Room lost part of its range: $reason');
            }
            previousStride = stride;
            painter.dispose();
          }
        }
      }
    });
  }

  testWidgets('rhyme colors retain text and composing underlines',
      (tester) async {
    final controller = LyricTextEditingController(text: 'hello world');
    addTearDown(controller.dispose);
    controller.spanBuilder = (text, style) => TextSpan(style: style, children: [
          TextSpan(
              text: text.substring(0, 6),
              style: const TextStyle(color: Colors.blue)),
          TextSpan(
              text: text.substring(6),
              style: const TextStyle(color: Colors.pink)),
        ]);
    controller.value =
        controller.value.copyWith(composing: const TextRange(start: 3, end: 8));
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      final span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(fontSize: 18),
          withComposing: true);
      expect(span.toPlainText(), controller.text);
      var underlined = '';
      span.visitChildren((span) {
        if (span is TextSpan &&
            span.style?.decoration == TextDecoration.underline) {
          underlined += span.text ?? '';
        }
        return true;
      });
      expect(underlined, 'lo wo');
      return const SizedBox();
    })));
  });
}
