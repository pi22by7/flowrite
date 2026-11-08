import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite/models/lyric_document.dart';
import 'package:flowrite/utils/song_preview.dart';

void main() {
  test('keeps the existing two-line lyric excerpt', () {
    expect(
      songPreview(
          '# Test song\n\nThese are song lyrics\nHow does this work\nMore'),
      'These are song lyrics How does this work',
    );
  });

  test('decodes chords and skips headings before selecting lyric lines', () {
    const lyrics =
        '## Chorus\nMorning comes\n\n## Verse\nCoffee and radio\nMore';
    final body =
        const LyricDocument(lyrics, [LyricChord(10, 17, 'C')]).encode();
    expect(songPreview('# Test song\n$body'), 'Morning comes Coffee and radio');
  });

  test('preserves literal brackets and escapes in encoded lyrics', () {
    const lyrics = 'Here [we] \\ go';
    final body =
        const LyricDocument(lyrics, [LyricChord(0, 4, 'D/F#')]).encode();
    expect(songPreview('# Test song\n$body'), lyrics);
    expect(songPreview('# Legacy song\n[Chorus]\n[C] is a lyric'),
        '[Chorus] [C] is a lyric');
  });

  test('handles lyrics saved without a title', () {
    expect(songPreview('First line\nSecond line\nThird'),
        'First line Second line');
    expect(songPreview('Just one line'), 'Just one line');
  });

  test('empty and heading-only songs use the empty-preview prompt', () {
    for (final content in [
      '',
      '# Title',
      '# Title\n',
      '# Title\n## Chorus\n\n### Verse\n'
    ]) {
      expect(songPreview(content), isEmpty);
    }
  });
}
