import 'package:flutter/material.dart';
import '../utils/markdown_headings.dart';
import '../models/lyric_document.dart';

/// Colors the editable text itself, so glyphs, selection and the caret share
/// one paragraph layout. Composing ranges retain their native underline.
class LyricTextEditingController extends TextEditingController {
  LyricTextEditingController({super.text});

  ({TextEditingValue before, TextEditingValue after})? _lastTextChange;

  LyricDocument updateDocument(LyricDocument document) {
    final change = _lastTextChange;
    if (change == null ||
        change.before.text != document.text ||
        change.after.text != text) {
      return document.edit(text);
    }
    final selection = change.before.selection;
    final caret = change.after.selection;
    return document.edit(
      text,
      selectionStart: selection.isValid ? selection.start : null,
      selectionEnd: selection.isValid ? selection.end : null,
      caretOffset:
          caret.isValid && caret.isCollapsed ? caret.extentOffset : null,
    );
  }

  @override
  set value(TextEditingValue next) {
    final selection = next.selection;
    final offset = selection.extentOffset;
    // A downstream caret at a hard newline can use the newline's bounds,
    // which exclude preceding spaces. Anchor to the typed space instead.
    if (selection.isValid &&
        selection.isCollapsed &&
        offset > 0 &&
        offset < next.text.length &&
        next.text[offset] == '\n' &&
        (next.text[offset - 1] == ' ' || next.text[offset - 1] == '\t') &&
        selection.affinity != TextAffinity.upstream) {
      next = next.copyWith(
          selection: TextSelection.collapsed(
              offset: offset, affinity: TextAffinity.upstream));
    }
    final previous = super.value;
    if (previous.text != next.text) {
      _lastTextChange = (before: previous, after: next);
    }
    super.value = next;
  }

  TextSpan Function(String text, TextStyle style)? spanBuilder;

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    if (style == null) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final colored =
        spanBuilder?.call(text, style) ?? buildLyricMarkdownSpan(text, style);
    if (!withComposing ||
        !value.isComposingRangeValid ||
        value.composing.isCollapsed) {
      return TextSpan(style: style, children: [colored]);
    }
    var offset = 0;
    TextSpan underline(TextSpan span) {
      final parts = <InlineSpan>[];
      final content = span.text ?? '';
      final start =
          value.composing.start.clamp(offset, offset + content.length) - offset;
      final end =
          value.composing.end.clamp(offset, offset + content.length) - offset;
      if (start > 0) parts.add(TextSpan(text: content.substring(0, start)));
      if (end > start) {
        parts.add(TextSpan(
            text: content.substring(start, end),
            style: const TextStyle(decoration: TextDecoration.underline)));
      }
      if (end < content.length) {
        parts.add(TextSpan(text: content.substring(end)));
      }
      offset += content.length;
      for (final child in span.children ?? const <InlineSpan>[]) {
        parts.add(child is TextSpan ? underline(child) : child);
      }
      return TextSpan(style: span.style, children: parts);
    }

    return TextSpan(style: style, children: [underline(colored)]);
  }
}

/// Keep extra line spacing symmetric around the actual font's glyph metrics.
/// This lets Flutter center a normal sized caret beside the letters even when
/// the strut includes room for a chord row.
TextStyle lyricLayoutStyle(
  TextStyle style, {
  bool hasChords = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final base = style.copyWith(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontWeight: style.fontWeight ?? FontWeight.w400,
    fontStyle: style.fontStyle ?? FontStyle.normal,
    leadingDistribution: TextLeadingDistribution.even,
  );
  if (!hasChords) return base;
  final size = textScaler.scale(style.fontSize!);
  final extra = lyricChordLabelHeight(style, textScaler) +
      12 +
      (lyricFontMetrics(base, textScaler).height - size)
          .clamp(0.0, double.infinity);
  // Add a fixed chord allowance; every Breathing Room step still has its
  // original effect. Include this in the text style as well as the strut so
  // Flutter gives the glyphs and the caret the same vertical metrics.
  return base.copyWith(height: (style.height ?? 1) + extra / size);
}

double lyricChordFontSize(TextStyle style) =>
    (style.fontSize! * 0.85).clamp(13.0, 20.0);

double lyricChordLabelHeight(TextStyle style, TextScaler scaler) =>
    scaler.scale(lyricChordFontSize(style)) * 1.2 + 4;

({double ascent, double height}) lyricFontMetrics(
    TextStyle style, TextScaler scaler) {
  final font = TextPainter(
    text: TextSpan(
        text: 'M',
        style: lyricLayoutStyle(style).copyWith(height: kTextHeightNone)),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final metrics =
      (ascent: font.computeLineMetrics().single.ascent, height: font.height);
  font.dispose();
  return metrics;
}

StrutStyle lyricStrutStyle(
  TextStyle style, {
  bool hasChords = false,
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    StrutStyle.fromTextStyle(
      lyricLayoutStyle(style, hasChords: hasChords, textScaler: textScaler),
      forceStrutHeight: true,
    );

double lyricChordTop(double baseline, TextStyle style, TextScaler scaler) =>
    baseline -
    lyricFontMetrics(style, scaler).ascent -
    lyricChordLabelHeight(style, scaler) -
    6;

double lyricChordTopInset(
        double firstBaseline, TextStyle style, TextScaler scaler) =>
    (-lyricChordTop(firstBaseline, style, scaler)).clamp(0.0, double.infinity);

// TextField reserves its two-pixel caret plus a one-pixel gap when wrapping.
double lyricParagraphWidth(double width) =>
    (width - 3).clamp(0.0, double.infinity);

class LyricTextField extends StatelessWidget {
  final LyricTextEditingController controller;
  final FocusNode? focusNode;
  final bool hasChords;
  final TextStyle style;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final Animation<double>? animation;

  const LyricTextField(
      {super.key,
      required this.controller,
      this.focusNode,
      this.hasChords = false,
      required this.style,
      this.contextMenuBuilder,
      this.animation});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final layoutStyle =
        lyricLayoutStyle(style, hasChords: hasChords, textScaler: scaler);
    final cursorHeight = lyricFontMetrics(layoutStyle, scaler).height;

    Widget field() => TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          style: layoutStyle,
          strutStyle:
              lyricStrutStyle(style, hasChords: hasChords, textScaler: scaler),
          cursorHeight: cursorHeight,
          cursorColor: Theme.of(context).colorScheme.primary,
          decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Write your song lyrics here...',
              hintStyle: layoutStyle.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
              contentPadding: EdgeInsets.zero,
              isDense: true),
          selectionControls: materialTextSelectionHandleControls,
          enableInteractiveSelection: true,
          contextMenuBuilder: contextMenuBuilder,
        );
    return animation == null
        ? field()
        : AnimatedBuilder(
            animation: animation!,
            builder: (context, child) => field(),
          );
  }
}
