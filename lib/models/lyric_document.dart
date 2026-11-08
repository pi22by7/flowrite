/// A lyric range and the chord displayed above its first character.
class LyricChord {
  final int start;
  final int end;
  final String label;

  const LyricChord(this.start, this.end, this.label);
}

/// Plain lyrics in memory; marked ChordPro text on disk. The marker ensures
/// existing songs containing bracketed text are never interpreted as chords.
class LyricDocument {
  static const marker = '{comment: Flowrite chords v1}\n';
  final String text;
  final List<LyricChord> chords;

  const LyricDocument(this.text, [this.chords = const []]);

  factory LyricDocument.decode(String source) {
    if (!source.startsWith(marker)) return LyricDocument(source);
    final text = StringBuffer();
    final chords = <LyricChord>[];
    final body = source.substring(marker.length);
    for (var i = 0; i < body.length; i++) {
      if (body[i] == '\\' && i + 1 < body.length) {
        text.write(body[++i]);
      } else if (body[i] == '[') {
        final close = body.indexOf(']', i + 1);
        if (close < 0) {
          text.write(body[i]);
        } else {
          chords.add(LyricChord(
              text.length, text.length, body.substring(i + 1, close)));
          i = close;
        }
      } else {
        text.write(body[i]);
      }
    }
    final lyrics = text.toString();
    return LyricDocument(lyrics, [
      for (final chord in chords)
        LyricChord(chord.start, wordEnd(lyrics, chord.start), chord.label),
    ]);
  }

  String encode() {
    if (chords.isEmpty) return text;
    final buffer = StringBuffer(marker);
    final sorted = [...chords]..sort((a, b) => a.start.compareTo(b.start));
    var next = 0;
    for (var i = 0; i <= text.length; i++) {
      while (next < sorted.length && sorted[next].start == i) {
        buffer.write('[${sorted[next++].label}]');
      }
      if (i < text.length) {
        if ('\\[]'.contains(text[i])) buffer.write('\\');
        buffer.write(text[i]);
      }
    }
    return buffer.toString();
  }

  static int wordEnd(String text, int start) {
    var end = start;
    while (end < text.length && !RegExp(r'\s').hasMatch(text[end])) {
      end++;
    }
    return end;
  }

  /// Map anchors through the actual selected/caret edit when available.
  /// Identical letters on either side cannot identify where typing happened.
  /// Insertions at the lyric's start belong before it; deleting it removes it.
  LyricDocument edit(
    String newText, {
    int? selectionStart,
    int? selectionEnd,
    int? caretOffset,
  }) {
    if (newText == text) return this;
    final lengthDelta = newText.length - text.length;
    ({int start, int oldEnd, int newEnd})? change;

    bool useRange(int start, int end) {
      final insertedLength = lengthDelta + end - start;
      final newEnd = start + insertedLength;
      if (start < 0 ||
          end < start ||
          end > text.length ||
          insertedLength < 0 ||
          newEnd > newText.length ||
          text.substring(0, start) != newText.substring(0, start) ||
          text.substring(end) != newText.substring(newEnd)) {
        return false;
      }
      change = (start: start, oldEnd: end, newEnd: newEnd);
      return true;
    }

    if (selectionStart != null &&
        selectionEnd != null &&
        selectionStart >= 0 &&
        selectionEnd >= selectionStart &&
        selectionEnd <= text.length) {
      if (selectionStart != selectionEnd) {
        useRange(selectionStart, selectionEnd);
      } else if (lengthDelta > 0) {
        useRange(selectionStart, selectionStart);
      } else if (lengthDelta < 0) {
        if (caretOffset == selectionStart) {
          useRange(selectionStart, selectionStart - lengthDelta);
        } else {
          useRange(selectionStart + lengthDelta, selectionStart);
        }
      }
    }
    if (change == null && caretOffset != null) {
      if (lengthDelta > 0) {
        useRange(caretOffset - lengthDelta, caretOffset - lengthDelta);
      } else if (lengthDelta < 0) {
        useRange(caretOffset, caretOffset - lengthDelta);
      }
    }
    // Programmatic changes and IME replacements can affect a different range
    // from the selection. Fall back only when the actual edit doesn't match.
    if (change == null) {
      var prefix = 0;
      while (prefix < text.length &&
          prefix < newText.length &&
          text[prefix] == newText[prefix]) {
        prefix++;
      }
      var oldEnd = text.length;
      var newEnd = newText.length;
      while (oldEnd > prefix &&
          newEnd > prefix &&
          text[oldEnd - 1] == newText[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
      change = (start: prefix, oldEnd: oldEnd, newEnd: newEnd);
    }
    final prefix = change!.start;
    final oldEnd = change!.oldEnd;
    final newEnd = change!.newEnd;
    final delta = newEnd - oldEnd;
    final mapped = <LyricChord>[];
    for (final chord in chords) {
      if (oldEnd > prefix &&
          prefix <= chord.start &&
          oldEnd >= chord.end &&
          chord.end > chord.start) {
        continue;
      }
      if (chord.start >= oldEnd) {
        mapped.add(
            LyricChord(chord.start + delta, chord.end + delta, chord.label));
      } else if (chord.end <= prefix) {
        mapped.add(chord);
      } else {
        mapped.add(LyricChord(
          chord.start < prefix ? chord.start : prefix,
          chord.end >= oldEnd ? chord.end + delta : newEnd,
          chord.label,
        ));
      }
    }
    return LyricDocument(newText, mapped);
  }
}
