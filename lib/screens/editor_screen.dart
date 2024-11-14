import 'package:flutter/material.dart';
import '../models/writing_file.dart';
import '../services/syllable_service.dart';

class EditorScreen extends StatefulWidget {
  final WritingFile file;

  const EditorScreen({super.key, required this.file});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final SyllableService _syllableService = SyllableService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<int> _syllableCounts = [];
  int _currentLine = 0;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _loadContent() async {
    final content = await widget.file.readContent();
    _controller.text = content;
    _updateSyllableCounts();
  }

  void _onTextChanged() {
    _updateSyllableCounts();
    _updateCurrentLine();
  }

  void _updateSyllableCounts() {
    setState(() {
      _syllableCounts = _controller.text
          .split('\n')
          .map((line) => _syllableService.countSyllables(line))
          .toList();
    });
  }

  void _updateCurrentLine() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final beforeCursor = text.substring(0, selection.start);
    final newLineCount = '\n'.allMatches(beforeCursor).length;

    setState(() {
      _currentLine = newLineCount;
    });
  }

  List<Map<String, dynamic>> _getLineOffsets(TextPainter textPainter) {
    List<Map<String, dynamic>> offsets = [];
    final lineMetrics = textPainter.computeLineMetrics();

    double accumulatedHeight = 0.0;
    for (var line in lineMetrics) {
      offsets.add({
        'offset': accumulatedHeight,
        'height': line.height,
      });
      accumulatedHeight += line.height;
    }

    return offsets;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final theme = Theme.of(context);
        final textStyle = TextStyle(
          fontSize: 16,
          height: 1.5,
          color: theme.colorScheme.onSurface,
        );

        const syllableCountsWidth = 50.0;
        const paddingHorizontal = 16.0 * 2; // Left and right padding
        final textAreaWidth =
            constraints.maxWidth - syllableCountsWidth - paddingHorizontal;

        final textPainter = TextPainter(
          text: TextSpan(text: _controller.text, style: textStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          textScaler: MediaQuery.textScalerOf(context),
          textHeightBehavior: const TextHeightBehavior(),
          locale: Localizations.localeOf(context),
          maxLines: null,
        );

        textPainter.layout(maxWidth: textAreaWidth);

        final lineOffsets = _getLineOffsets(textPainter);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.file.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveContent,
              ),
            ],
          ),
          body: SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Stack(
                children: [
                  SizedBox(
                    width: textAreaWidth + paddingHorizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: EditableText(
                        controller: _controller,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        style: textStyle,
                        cursorColor: theme.colorScheme.primary,
                        backgroundCursorColor: theme.colorScheme.surface,
                        selectionControls: materialTextSelectionControls,
                        onSelectionChanged: (selection, _) {
                          _updateCurrentLine();
                        },
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SyllableCountPainter(
                          lineOffsets: lineOffsets,
                          syllableCounts: _syllableCounts,
                          currentLine: _currentLine,
                          textStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          highlightColor:
                          theme.colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveContent() async {
    await widget.file.writeContent(_controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _SyllableCountPainter extends CustomPainter {
  final List<Map<String, dynamic>> lineOffsets;
  final List<int> syllableCounts;
  final int currentLine;
  final TextStyle textStyle;
  final Color highlightColor;

  _SyllableCountPainter({
    required this.lineOffsets,
    required this.syllableCounts,
    required this.currentLine,
    required this.textStyle,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = highlightColor;

    for (int i = 0; i < lineOffsets.length && i < syllableCounts.length; i++) {
      final lineInfo = lineOffsets[i];
      final offsetY = lineInfo['offset'] as double;
      final height = lineInfo['height'] as double;

      // Draw highlight for current line
      if (i == currentLine) {
        canvas.drawRect(
          Rect.fromLTWH(0, offsetY, size.width, height),
          paint,
        );
      }

      final textSpan = TextSpan(
        text: '${syllableCounts[i]}',
        style: textStyle.copyWith(
          fontWeight: i == currentLine ? FontWeight.bold : FontWeight.normal,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout(minWidth: 0, maxWidth: 50);

      // Position the text at the right side
      final position = Offset(
        size.width - textPainter.width - 16, // Adjust padding if necessary
        offsetY + (height - textPainter.height) / 2, // Center vertically
      );

      textPainter.paint(canvas, position);
    }
  }

  @override
  bool shouldRepaint(covariant _SyllableCountPainter oldDelegate) {
    return oldDelegate.lineOffsets != lineOffsets ||
        oldDelegate.syllableCounts != syllableCounts ||
        oldDelegate.currentLine != currentLine;
  }
}
