import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/writing_file.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../services/rhyme_service.dart';
import '../services/syllable_service.dart';
import '../widgets/settings_panel.dart';

class EditorScreen extends StatefulWidget {
  final WritingFile file;

  const EditorScreen({super.key, required this.file});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final SyllableService _syllableService = SyllableService();
  final RhymeService _rhymeService = RhymeService();
  final FileService _fileService = FileService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<int> _syllableCounts = [];
  int _currentLine = 0;
  bool _isSaving = false;
  // String _saveStatus = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _loadContent() async {
    _rhymeService.reset();
    final content = await widget.file.readContent();
    _controller.text = content;
    _updateSyllableCounts();
  }

  void _onTextChanged() {
    _rhymeService.reset();
    _updateSyllableCounts();
    _updateCurrentLine();
  }

  void _updateSyllableCounts() {
    setState(() {
      _syllableCounts = _controller.text
          .split('\n')
          .map((line) => _syllableService.countSyllablesInText(line))
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

  TextSpan _buildColoredTextSpan(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }

      final lineSpans = _colorWordsInLine(lines[i], baseStyle);
      spans.addAll(lineSpans);
    }

    return TextSpan(children: spans);
  }

  List<TextSpan> _colorWordsInLine(String line, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    // If rhyme coloring is disabled, return the whole line as one span
    if (!settings.showRhymes) {
      return [TextSpan(text: line, style: baseStyle)];
    }

    // Updated regex pattern to handle special characters better
    final pattern = RegExp(r'([^\s]+|\s+)');
    final matches = pattern.allMatches(line);

    for (final match in matches) {
      final word = match.group(0)!;
      if (RegExp(r'\s+').hasMatch(word)) {
        spans.add(TextSpan(text: word, style: baseStyle));
      } else {
        // Extract only letters for rhyme checking
        final letters = word.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');
        final color = letters.isEmpty
            ? baseStyle.color!
            : _rhymeService.getRhymeColor(letters);
        spans.add(TextSpan(
          text: word,
          style: baseStyle.copyWith(color: color),
        ));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final settings = Provider.of<SettingsProvider>(context);

        final textStyle = TextStyle(
          fontFamily: settings.fontFamily,
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colorScheme.onSurface,
          letterSpacing: 0.2,
        );

        const syllableCountsWidth = 50.0;
        const paddingHorizontal = 16.0 * 2;
        final textAreaWidth =
            constraints.maxWidth - syllableCountsWidth - paddingHorizontal;

        final textPainter = TextPainter(
          text: _buildColoredTextSpan(_controller.text, textStyle),
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
            centerTitle: true,
            title: Column(
              children: [
                Text(
                  widget.file.name,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${_syllableCounts.length} lines',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(153),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.settings,
                  color: colorScheme.primary,
                ),
                onPressed: () => _showSettings(context),
              ),
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveContent,
                ),
            ],
            elevation: 0,
            backgroundColor: colorScheme.surface,
          ),
          body: Container(
            color: colorScheme.surface,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    Container(
                      width: textAreaWidth + paddingHorizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                      ),
                      child: Stack(
                        children: [
                          RichText(
                            text: _buildColoredTextSpan(
                                _controller.text, textStyle),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            textScaler: MediaQuery.textScalerOf(context),
                            strutStyle: StrutStyle(
                              fontSize: textStyle.fontSize,
                              height: textStyle.height,
                              forceStrutHeight: true,
                            ),
                          ),
                          EditableText(
                            controller: _controller,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            style: textStyle.copyWith(
                              color: Colors
                                  .transparent, // Make the editing text transparent
                            ),
                            cursorColor: colorScheme.primary,
                            backgroundCursorColor: colorScheme.surface,
                            selectionColor: colorScheme.primary.withAlpha(51),
                            cursorWidth: 2.0,
                            cursorRadius: const Radius.circular(1),
                            selectionControls: materialTextSelectionControls,
                            onSelectionChanged: (selection, _) {
                              _updateCurrentLine();
                            },
                            strutStyle: StrutStyle(
                              fontSize: textStyle.fontSize,
                              height: textStyle.height,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (settings.showSyllables)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SyllableCountPainter(
                              lineOffsets: lineOffsets,
                              syllableCounts: _syllableCounts,
                              currentLine: _currentLine,
                              textStyle: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              highlightColor: colorScheme.primary.withAlpha(12),
                              activeTextColor: colorScheme.primary,
                              inactiveTextColor:
                                  colorScheme.onSurface.withAlpha(102),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: const SettingsPanel(),
        ),
      ),
    );
  }

  Future<void> _saveContent() async {
    setState(() {
      _isSaving = true;
      // _saveStatus = 'Saving...';
    });

    try {
      final (success, message) = await _fileService.saveFile(
        widget.file,
        _controller.text,
      );

      // setState(() {
      //   _saveStatus = message;
      // });

      // Show snackbar with status
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            backgroundColor: success
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      // setState(() {
      //   _saveStatus = 'Error saving file';
      // });
    } finally {
      setState(() {
        _isSaving = false;
      });
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
  final Color activeTextColor;
  final Color inactiveTextColor;

  _SyllableCountPainter({
    required this.lineOffsets,
    required this.syllableCounts,
    required this.currentLine,
    required this.textStyle,
    required this.highlightColor,
    required this.activeTextColor,
    required this.inactiveTextColor,
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
        final highlightRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, offsetY, size.width, height),
          const Radius.circular(8),
        );
        canvas.drawRRect(highlightRect, paint);
      }

      final textSpan = TextSpan(
        text: '${syllableCounts[i]}',
        style: textStyle.copyWith(
          color: i == currentLine ? activeTextColor : inactiveTextColor,
          fontWeight: i == currentLine ? FontWeight.bold : FontWeight.normal,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout(minWidth: 0, maxWidth: 50);

      final position = Offset(
        size.width - textPainter.width - 24,
        offsetY + (height - textPainter.height) / 2,
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
