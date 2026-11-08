import '../models/lyric_document.dart';
import 'markdown_headings.dart';

/// The first two lyric lines, without the saved title or editor formatting.
String songPreview(String content) {
  final titleEnd = content.indexOf('\n');
  final body = content.startsWith('# ')
      ? (titleEnd < 0 ? '' : content.substring(titleEnd + 1))
      : content;
  return LyricDocument.decode(body)
      .text
      .split('\n')
      .where((line) => line.trim().isNotEmpty && !isMarkdownHeading(line))
      .take(2)
      .join(' ');
}
