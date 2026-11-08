import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/models/lyric_document.dart';

void main() {
  test('existing bracketed lyrics remain literal', () {
    const text = '[Chorus]\n[C] is a lyric, not a chord';
    expect(LyricDocument.decode(text).text, text);
    expect(LyricDocument.decode(text).chords, isEmpty);
  });

  test('chords and escaped lyrics survive saving and reopening', () {
    const text = 'Here [we] \\ go\nagain';
    const document = LyricDocument(
        text, [LyricChord(5, 9, 'D/F#'), LyricChord(15, 20, 'Am7')]);
    final reopened = LyricDocument.decode(document.encode());
    expect(reopened.text, text);
    expect(reopened.chords.map((c) => c.start), [5, 15]);
    expect(reopened.chords.map((c) => c.label), ['D/F#', 'Am7']);
    expect(reopened.encode(), document.encode());
  });

  test('chord follows lyric through insertion, newline, and deletion before it',
      () {
    var document = const LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    document = document.edit('hello bright\nworld');
    expect(document.chords.single.start, 13);
    document = document.edit('world');
    expect(document.chords.single.start, 0);
    expect(document.chords.single.end, 5);
    document = document.edit('new world');
    expect(document.chords.single.start, 4);
  });

  test('partial lyric edits retain chord; deleting attached lyric removes it',
      () {
    var document = const LyricDocument('hello world', [LyricChord(6, 11, 'C')]);
    document = document.edit('hello word');
    expect(document.chords.single.start, 6);
    expect(document.chords.single.end, 10);
    document = document.edit('hello ');
    expect(document.chords, isEmpty);
    expect(document.encode(), 'hello ');
  });

  test('editing lyrics after a chord leaves its range unchanged', () {
    final document = const LyricDocument('hello world', [LyricChord(0, 5, 'G')])
        .edit('hello moon');
    expect(document.chords.single.start, 0);
    expect(document.chords.single.end, 5);
  });
}
