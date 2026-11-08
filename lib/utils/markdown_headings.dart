import 'package:flutter/material.dart';

/// ATX Markdown headings. Keep the source characters in the editable text so
/// selection, chord anchors, undo and plain-text exports keep their offsets.
final markdownHeadingPattern = RegExp(r'^ {0,3}#{1,6}[ \t]');
final _visibleHeadingPrefix = RegExp(r'^( {0,3})#{1,6}[ \t]');
final _headingPrefix = RegExp(r'^ {0,3}#{1,6}(?:[ \t]+|$)');

bool isMarkdownHeading(String line) => markdownHeadingPattern.hasMatch(line);

TextSpan buildLyricMarkdownSpan(String text, TextStyle style,
    {List<TextSpan> Function(String, TextStyle)? lyricLineBuilder}) {
  final spans = <TextSpan>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(TextSpan(text: '\n', style: style));
    final line = lines[i];
    if (isMarkdownHeading(line)) {
      final prefix = _visibleHeadingPrefix.firstMatch(line)!;
      final indentEnd = prefix.group(1)!.length;
      final prefixEnd = prefix.end;
      final headingStyle = style.copyWith(fontWeight: FontWeight.w700);
      spans.add(TextSpan(style: headingStyle, children: [
        // Retain Markdown source offsets for editing and chord anchors, but
        // give the syntax no visual width. The section name is the heading.
        if (indentEnd > 0)
          TextSpan(text: line.substring(0, indentEnd), style: headingStyle),
        TextSpan(
            text: line.substring(indentEnd, prefixEnd),
            style: style.copyWith(
              fontSize: 0,
              letterSpacing: 0,
              wordSpacing: 0,
              color: Colors.transparent,
            )),
        TextSpan(text: line.substring(prefixEnd), style: headingStyle),
      ]));
    } else {
      spans.addAll(lyricLineBuilder?.call(line, style) ??
          [TextSpan(text: line, style: style)]);
    }
  }
  return TextSpan(style: style, children: spans);
}

int _lineStart(TextEditingValue value) {
  final offset =
      value.selection.isValid ? value.selection.start : value.text.length;
  return offset == 0 ? 0 : value.text.lastIndexOf('\n', offset - 1) + 1;
}

/// Insert above the current lyric line, preserving the lyric and its chords.
TextEditingValue insertSectionHeading(TextEditingValue value, String label) {
  final start = _lineStart(value);
  final heading = '## $label\n';
  return TextEditingValue(
    text: value.text.replaceRange(start, start, heading),
    selection: TextSelection.collapsed(offset: start + heading.length),
  );
}

/// Format just the current line. Existing Markdown prefixes are replaced.
TextEditingValue formatSectionHeading(TextEditingValue value,
    {bool remove = false}) {
  final start = _lineStart(value);
  final endOfLine = value.text.indexOf('\n', start);
  final end = endOfLine < 0 ? value.text.length : endOfLine;
  final line = value.text.substring(start, end);
  final prefix = _headingPrefix.firstMatch(line)?.end ?? 0;
  final body = line.substring(prefix);
  final replacement = remove ? body : '## ${body.isEmpty ? 'Section' : body}';
  return TextEditingValue(
    text: value.text.replaceRange(start, end, replacement),
    selection: !remove && body.isEmpty
        ? TextSelection(
            baseOffset: start + 3, extentOffset: start + replacement.length)
        : TextSelection.collapsed(offset: start + replacement.length),
  );
}
