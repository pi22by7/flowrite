import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lyric_document.dart';
import 'lyric_text_field.dart';
import '../utils/markdown_headings.dart';

/// Uses the same layout as the editable text, including wrapping and text scale.
class LyricChordLayer extends StatelessWidget {
  final LyricDocument document;
  final TextStyle style;
  final Widget child;
  final bool visible;
  final ValueChanged<LyricChord> onEdit;
  final LyricChord? editingChord;
  final void Function(LyricChord, String)? onCommit;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onDraftChanged;
  final void Function(LyricChord, int) onMove;

  const LyricChordLayer(
      {super.key,
      required this.document,
      required this.style,
      required this.child,
      this.visible = true,
      required this.onEdit,
      required this.onMove,
      this.editingChord,
      this.onCommit,
      this.onCancel,
      this.onDraftChanged});

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return LayoutBuilder(builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final hasChords = document.chords.isNotEmpty || editingChord != null;
      final painter = TextPainter(
        text: buildLyricMarkdownSpan(document.text,
            lyricLayoutStyle(style, hasChords: hasChords, textScaler: scaler)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        strutStyle:
            lyricStrutStyle(style, hasChords: hasChords, textScaler: scaler),
      )..layout(maxWidth: lyricParagraphWidth(constraints.maxWidth));
      final metrics = painter.computeLineMetrics();
      final chordFontSize = lyricChordFontSize(style);
      final topInset = hasChords && metrics.isNotEmpty
          ? lyricChordTopInset(metrics.first.baseline, style, scaler)
          : 0.0;
      final chordColor = Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF79BCD0)
          : const Color(0xFF2F7E98);

      final chordStyle = TextStyle(
        fontFamily: 'Roboto Mono',
        fontSize: chordFontSize,
        height: 1.2,
        color: chordColor,
        fontWeight: FontWeight.w600,
      );
      final labelHeight = lyricChordLabelHeight(style, scaler);
      double labelWidth(String label) {
        final measure = TextPainter(
            text: TextSpan(text: label, style: chordStyle),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context))
          ..layout();
        final width = measure.width + 4;
        measure.dispose();
        return width.clamp(20.0, constraints.maxWidth);
      }

      Widget chordLabel(LyricChord chord) => Material(
            type: MaterialType.transparency,
            child: SizedBox(
                width: labelWidth(chord.label),
                height: labelHeight,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(chord.label, style: chordStyle))),
          );
      final chords = [...document.chords];
      if (editingChord != null && !chords.contains(editingChord)) {
        chords.removeWhere((c) => c.start == editingChord!.start);
        chords.add(editingChord!);
      }

      return DragTarget<LyricChord>(
        onWillAcceptWithDetails: (details) =>
            document.chords.contains(details.data),
        onAcceptWithDetails: (details) {
          final box = context.findRenderObject()! as RenderBox;
          final local = box.globalToLocal(details.offset);
          final position =
              painter.getPositionForOffset(local - Offset(0, topInset));
          if (document.text.isEmpty) return;
          var offset = position.offset.clamp(0, document.text.length - 1);
          if (RegExp(r'\s').hasMatch(document.text[offset])) return;
          while (offset > 0 &&
              !RegExp(r'\s').hasMatch(document.text[offset - 1])) {
            offset--;
          }
          onMove(details.data, offset);
        },
        builder: (context, candidates, rejected) => Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(padding: EdgeInsets.only(top: topInset), child: child),
            for (final chord in chords)
              if (chord.start < document.text.length && metrics.isNotEmpty)
                Builder(builder: (context) {
                  final caret = painter.getOffsetForCaret(
                      TextPosition(offset: chord.start), Rect.zero);
                  final boxes = painter.getBoxesForSelection(
                    TextSelection(
                        baseOffset: chord.start,
                        extentOffset: (chord.end > chord.start
                                ? chord.end
                                : chord.start + 1)
                            .clamp(0, document.text.length)),
                    boxHeightStyle: ui.BoxHeightStyle.strut,
                  );
                  final centerY =
                      boxes.isEmpty ? caret.dy : boxes.first.toRect().center.dy;
                  final line = metrics.firstWhere(
                    (line) =>
                        centerY >= line.baseline - line.ascent - 0.01 &&
                        centerY < line.baseline + line.descent + 0.01,
                    orElse: () => metrics.last,
                  );
                  // Stay a fixed distance above the glyphs as line spacing changes.
                  return Positioned(
                    left: caret.dx.clamp(
                        0.0,
                        (constraints.maxWidth - 40)
                            .clamp(0.0, double.infinity)),
                    top: lyricChordTop(line.baseline, style, scaler) + topInset,
                    width: chord == editingChord
                        ? (labelWidth(chord.label) + 80)
                            .clamp(80.0, constraints.maxWidth)
                        : labelWidth(chord.label),
                    height: labelHeight,
                    child: chord == editingChord
                        ? _InlineChordEditor(
                            key: ObjectKey(chord),
                            chord: chord,
                            style: chordStyle,
                            onCommit: (label) => onCommit?.call(chord, label),
                            onCancel: () => onCancel?.call(),
                            onDraftChanged: onDraftChanged,
                          )
                        : Draggable<LyricChord>(
                            data: chord,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: chordLabel(chord),
                            childWhenDragging:
                                Opacity(opacity: 0.3, child: chordLabel(chord)),
                            child: Semantics(
                              label:
                                  'Chord ${chord.label}. Drag to move, tap to edit.',
                              button: true,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.grab,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onEdit(chord),
                                  child: chordLabel(chord),
                                ),
                              ),
                            ),
                          ),
                  );
                }),
          ],
        ),
      );
    });
  }
}

class _InlineChordEditor extends StatefulWidget {
  final LyricChord chord;
  final TextStyle style;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;
  final ValueChanged<String>? onDraftChanged;
  const _InlineChordEditor(
      {super.key,
      required this.chord,
      required this.style,
      required this.onCommit,
      required this.onCancel,
      this.onDraftChanged});

  @override
  State<_InlineChordEditor> createState() => _InlineChordEditorState();
}

class _InlineChordEditorState extends State<_InlineChordEditor> {
  late final _controller = TextEditingController(text: widget.chord.label);
  final _focus = FocusNode();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_finished) return;
    _finished = true;
    widget.onCommit(_controller.text.trim());
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _finished = true;
            widget.onCancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          key: const ValueKey('inline-chord-input'),
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          style: widget.style,
          cursorHeight:
              MediaQuery.textScalerOf(context).scale(widget.style.fontSize!),
          decoration: const InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(vertical: 2),
              border: UnderlineInputBorder(),
              hintText: 'Chord'),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\[\]\\\r\n]')),
            LengthLimitingTextInputFormatter(24),
          ],
          onChanged: widget.onDraftChanged,
          onSubmitted: (_) => _commit(),
          onTapOutside: (_) => _commit(),
        ),
      );
}
