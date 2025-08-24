import 'dart:async';
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
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<int> _syllableCounts = [];
  int _currentLine = 0;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isAutoSaving = false;
  String _originalTitle = '';
  String _originalContent = '';
  Timer? _autosaveTimer;
  Future<void>? _currentSaveOperation;
  // String _saveStatus = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
    _controller.addListener(_onTextChanged);
    _titleController.addListener(_onTitleChanged);
    _focusNode.addListener(_onBodyFocusChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    _initializeRhymeService();
  }

  void _onBodyFocusChanged() {
    if (!_focusNode.hasFocus && _hasUnsavedChanges) {
      _saveOnBlur();
    }
  }

  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus && _hasUnsavedChanges) {
      _saveOnBlur();
    }
  }

  void _saveOnBlur() {
    // Cancel any pending autosave timer since we're saving now
    _autosaveTimer?.cancel();
    if (_hasUnsavedChanges && _currentSaveOperation == null) {
      _currentSaveOperation = _autoSave();
    }
  }

  Future<void> _initializeRhymeService() async {
    try {
      await _rhymeService.initialize();
      if (mounted) {
        setState(() {}); // Refresh UI to show CMU status
      }
    } catch (e) {
      debugPrint('Failed to initialize rhyme service: $e');
    }
  }

  Future<void> _loadContent() async {
    _rhymeService.reset();
    final content = await widget.file.readContent();

    // Split content into title and body if it contains a separator
    String title = widget.file.name;
    String body = content;

    if (content.startsWith('# ')) {
      // Look for the first line starting with '# ' as title
      final lines = content.split('\n');
      if (lines.isNotEmpty && lines[0].startsWith('# ')) {
        title = lines[0].substring(2).trim(); // Remove '# ' prefix
        body = lines.length > 1 ? lines.sublist(1).join('\n').trimLeft() : '';
      }
    }

    _titleController.text = title;
    _controller.text = body;
    _originalTitle = title;
    _originalContent = body;
    _updateSyllableCounts();
  }

  void _onTextChanged() {
    _rhymeService.reset();
    _updateSyllableCounts();
    _updateCurrentLine();
    _checkForChanges();
    _startAutosaveTimer();
  }

  void _onTitleChanged() {
    _checkForChanges();
    _startAutosaveTimer();
  }

  void _checkForChanges() {
    setState(() {
      _hasUnsavedChanges = _titleController.text != _originalTitle ||
          _controller.text != _originalContent;
    });
  }

  void _startAutosaveTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), () {
      if (_hasUnsavedChanges && _currentSaveOperation == null) {
        _currentSaveOperation = _autoSave();
      }
    });
  }

  Future<void> _autoSave() async {
    return _performSave(showFeedback: false);
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        // Final fallback - only save if we still have unsaved changes
        // (onBlur should have handled most cases already)
        if (didPop && _hasUnsavedChanges && _currentSaveOperation == null) {
          // Quick fire-and-forget save, don't wait for it
          _autoSave();
        }
      },
      child: LayoutBuilder(
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
            backgroundColor: colorScheme.surface,
            body: SafeArea(
              child: Column(
                children: [
                  _buildMinimalAppBar(colorScheme, settings),
                  Expanded(
                    child: _buildEditor(
                      constraints,
                      textStyle,
                      colorScheme,
                      settings,
                      textAreaWidth,
                      paddingHorizontal,
                      lineOffsets,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMinimalAppBar(
      ColorScheme colorScheme, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleBackPress(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Song',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_syllableCounts.length} ${_syllableCounts.length == 1 ? 'line' : 'lines'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderButton(
                icon: Icons.settings_rounded,
                onPressed: () => _showSettings(context),
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                icon: (_isSaving || _isAutoSaving)
                    ? Icons.sync_rounded
                    : _hasUnsavedChanges
                        ? Icons.circle_outlined
                        : Icons.check_rounded,
                onPressed: (_isSaving || _isAutoSaving) ? null : _saveContent,
                colorScheme: colorScheme,
                isLoading: _isSaving || _isAutoSaving,
                showBadge: _hasUnsavedChanges && !_isAutoSaving,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ColorScheme colorScheme,
    bool isLoading = false,
    bool showBadge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: onPressed != null
                    ? colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: onPressed != null
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 20,
                      color: onPressed != null
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
            ),
            if (showBadge)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(
    BoxConstraints constraints,
    TextStyle textStyle,
    ColorScheme colorScheme,
    SettingsProvider settings,
    double textAreaWidth,
    double paddingHorizontal,
    List<Map<String, dynamic>> lineOffsets,
  ) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'Spectral',
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ) ??
        textStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w500);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          width: constraints.maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title field
              TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: titleStyle,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Song Title',
                  hintStyle: titleStyle.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                maxLines: 1,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _focusNode.requestFocus(),
              ),

              // Divider
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                height: 2,
                color: colorScheme.outline.withValues(alpha: 0.8),
              ),

              // Body content editor
              Stack(
                children: [
                  SizedBox(
                    width: textAreaWidth + paddingHorizontal,
                    child: Stack(
                      children: [
                        // Placeholder text when body is empty
                        if (_controller.text.isEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Padding(
                                padding: EdgeInsets.zero,
                                child: Text(
                                  'Write your song lyrics here...',
                                  style: textStyle.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                            color: Colors.transparent,
                          ),
                          cursorColor: colorScheme.primary,
                          backgroundCursorColor: colorScheme.surface,
                          selectionColor:
                              colorScheme.primary.withValues(alpha: 0.2),
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
                              color: colorScheme.primary.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            highlightColor:
                                colorScheme.primary.withValues(alpha: 0.05),
                            activeTextColor: colorScheme.primary,
                            inactiveTextColor:
                                colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  void _handleBackPress() {
    Navigator.pop(context);
  }

  Future<void> _saveContent() async {
    // Wait for any ongoing save operation to complete first
    if (_currentSaveOperation != null) {
      await _currentSaveOperation;
      return; // The ongoing operation will have saved our changes
    }

    _currentSaveOperation = _performSave(showFeedback: true);
    await _currentSaveOperation;
  }

  Future<void> _performSave({bool showFeedback = false}) async {
    setState(() {
      _isSaving =
          showFeedback; // Only show manual save indicator for manual saves
      if (!showFeedback) _isAutoSaving = true;
    });

    try {
      final title = _titleController.text.trim();
      final body = _controller.text;

      // Combine title and body content with markdown-style header
      String combinedContent = body;
      if (title.isNotEmpty) {
        combinedContent = '# $title\n$body';
      }

      // Save the content first
      final (success, message) = await _fileService.saveFile(
        widget.file,
        combinedContent,
      );

      // Then rename the file if title changed and save was successful
      if (success && title != widget.file.name && title.isNotEmpty) {
        await _fileService.renameFile(widget.file, title);
      }

      if (success && mounted) {
        setState(() {
          _originalTitle = _titleController.text;
          _originalContent = _controller.text;
          _hasUnsavedChanges = false;
        });
      }

      if (showFeedback && mounted) {
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
      debugPrint('Save failed: $e');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isAutoSaving = false;
        });
      }
      _currentSaveOperation = null;
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _controller.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _titleFocusNode.dispose();
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
