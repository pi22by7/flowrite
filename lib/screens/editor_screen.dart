import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/writing_file.dart';
import '../models/sync_operation.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/file_service.dart';
import '../services/rhyme_service.dart';
import '../services/syllable_service.dart';
import '../widgets/ambient_background.dart';
import '../widgets/settings_panel.dart';
import '../widgets/rhyme_dictionary_popup.dart';

class EditorScreen extends StatefulWidget {
  final WritingFile file;

  const EditorScreen({super.key, required this.file});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
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

  // Rhyme dictionary state
  bool _showRhymePopup = false;
  String _selectedText = '';
  Offset _popupPosition = Offset.zero;
  Timer? _selectionTimer;

  // Shimmer animation for selected word
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize shimmer animation for selected word
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOutSine,
      ),
    );

    _loadContent();
    _controller.addListener(_onTextChanged);
    _controller.addListener(_onSelectionChanged);
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

  void _onSelectionChanged() {
    _updateCurrentLine();
    
    // Cancel any existing timer
    _selectionTimer?.cancel();
    
    // If popup is open and we have a valid selection, update it
    if (_showRhymePopup) {
      final selection = _controller.selection;
      if (selection.isValid && !selection.isCollapsed) {
        final selectedText = _controller.text.substring(selection.start, selection.end).trim();
        if (selectedText.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(selectedText)) {
          debugPrint('🔄 Selection changed while popup open: "$_selectedText" -> "$selectedText"');
          if (_selectedText != selectedText) {
            // Update popup with new selection
            _showRhymeDictionary(selectedText, selection);
          }
          return; // Don't hide the popup, just update it
        }
      }
      // Hide popup if selection is invalid
      debugPrint('❌ Invalid selection, closing popup');
      setState(() {
        _showRhymePopup = false;
      });
    }
    
    // Trigger rebuild to update rhyme button highlighting
    if (mounted) {
      setState(() {});
    }
  }

  void _showRhymeDictionary(String text, TextSelection selection) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    // Responsive popup dimensions
    final popupWidth = (screenSize.width * 0.9).clamp(280.0, 400.0);
    final maxPopupHeight = screenSize.height * 0.6;
    
    double popupX, popupY;
    
    if (isTablet) {
      // Tablet: Show to the side if possible, otherwise center
      popupX = screenSize.width * 0.6;
      popupY = screenSize.height * 0.2;
      
      // Adjust if would go off screen
      if (popupX + popupWidth > screenSize.width - 20) {
        popupX = (screenSize.width - popupWidth) / 2;
      }
    } else {
      // Mobile: Center horizontally, position in bottom half
      popupX = (screenSize.width - popupWidth) / 2;
      popupY = screenSize.height * 0.4;
    }
    
    // Ensure popup stays within bounds
    popupX = popupX.clamp(10.0, screenSize.width - popupWidth - 10);
    popupY = popupY.clamp(100.0, screenSize.height - 100.0);
    
    // Adjust if would exceed max height
    if (popupY + maxPopupHeight > screenSize.height - 60) {
      popupY = screenSize.height - maxPopupHeight - 60;
    }

    setState(() {
      _selectedText = text;
      _popupPosition = Offset(popupX, popupY);
      _showRhymePopup = true;
    });
  }

  void _onRhymeWordTap(String rhymeWord) {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    // Replace selected text with the rhyme word
    final newText = _controller.text.replaceRange(
      selection.start,
      selection.end,
      rhymeWord,
    );

    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + rhymeWord.length,
      ),
    );

    setState(() {
      _showRhymePopup = false;
    });
  }

  void _closeRhymePopup() {
    setState(() {
      _showRhymePopup = false;
    });
  }

  void _showRhymePopupManually() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final selectedText = _controller.text.substring(selection.start, selection.end).trim();
    if (selectedText.isEmpty || !RegExp(r'[a-zA-Z]').hasMatch(selectedText)) return;

    _showRhymeDictionary(selectedText, selection);
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
    final colorScheme = Theme.of(context).colorScheme;

    // If rhyme coloring is disabled or focus mode is on, return the whole line as one span
    if (!settings.showRhymes || settings.focusMode) {
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

        // Check if this word matches the selected text for shimmer effect
        final isSelectedWord = _showRhymePopup &&
            _selectedText.isNotEmpty &&
            letters == _selectedText.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');

        // Apply shimmer effect to selected word
        if (isSelectedWord) {
          final shimmerValue = _shimmerAnimation.value;
          // Create a gentle shimmer that oscillates the alpha
          final shimmerAlpha = 0.15 + (0.15 * ((shimmerValue < 0.5 ? shimmerValue * 2 : (1 - shimmerValue) * 2)));
          spans.add(TextSpan(
            text: word,
            style: baseStyle.copyWith(
              color: color,
              backgroundColor: colorScheme.primary.withValues(alpha: shimmerAlpha),
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: word,
            style: baseStyle.copyWith(color: color),
          ));
        }
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
            backgroundColor: Colors.transparent,
            body: AmbientBackground(
              baseColor: colorScheme.surface,
              showTexture: false, // Disabled texture for cleaner look
              textureType: TextureType.paper,
              showGradient: false, // Disabled gradient for cleaner look
              child: Stack(
                children: [
                  // Very subtle vignette for gentle focus
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.5,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            colorScheme.surface.withValues(alpha: 0.1),
                          ],
                          stops: const [0.0, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Main content
                  SafeArea(
                    child: Stack(
                      children: [
                        Column(
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

                        // Rhyme dictionary popup overlay
                        if (_showRhymePopup)
                          RhymeDictionaryPopup(
                            key: ValueKey(_selectedText), // Force rebuild when text changes
                            selectedText: _selectedText,
                            position: _popupPosition,
                            onClose: _closeRhymePopup,
                            onWordTap: _onRhymeWordTap,
                          ),
                      ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        // Ghost-like: nearly transparent
        color: colorScheme.surface.withValues(alpha: 0.7),
        // Remove bottom border for cleaner look
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
                  // Ghost-style: nearly invisible
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.06),
                  ),
                  color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.3),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  // Ghost-style: more subtle
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
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
                Consumer<SyncProvider>(
                  builder: (context, syncProvider, child) {
                    String statusText = '${_syllableCounts.length} ${_syllableCounts.length == 1 ? 'line' : 'lines'}';

                    // Add sync status if signed in
                    if (syncProvider.isSignedIn) {
                      switch (syncProvider.syncStatus) {
                        case SyncStatus.syncing:
                          statusText += ' • Syncing...';
                          break;
                        case SyncStatus.pending:
                          statusText += ' • Pending sync';
                          break;
                        case SyncStatus.error:
                          statusText += ' • Sync error';
                          break;
                        case SyncStatus.synced:
                          statusText += ' • Synced';
                          break;
                        default:
                          break;
                      }
                    }

                    return Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderButton(
                icon: Icons.auto_awesome_rounded,
                onPressed: _showRhymePopupManually,
                colorScheme: colorScheme,
                isHighlighted: _controller.selection.isValid && !_controller.selection.isCollapsed,
              ),
              const SizedBox(width: 8),
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
    bool isHighlighted = false,
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
                color: isHighlighted 
                    ? colorScheme.primary.withValues(alpha: 0.2)
                    : onPressed != null
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHighlighted
                      ? colorScheme.primary
                      : onPressed != null
                          ? colorScheme.primary.withValues(alpha: 0.2)
                          : colorScheme.outline.withValues(alpha: 0.1),
                  width: isHighlighted ? 2 : 1,
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
      child: Center(
        // Center the content horizontally
        child: Container(
          // Max width for centered composition (journal-like)
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth > 800 ? 700 : constraints.maxWidth,
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

              // Ornamental divider - poetic and elegant
              Container(
                margin: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              colorScheme.outline.withValues(alpha: 0.2),
                              colorScheme.primary.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.fiber_manual_record,
                        size: 4,
                        color: colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.3),
                              colorScheme.outline.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body content editor
              Stack(
                children: [
                  SizedBox(
                    width: textAreaWidth + paddingHorizontal,
                    child: Stack(
                      children: [
                        // Base TextField for selection and editing
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          style: textStyle.copyWith(
                            // Make text transparent only when rhyme coloring is visible (not in focus mode)
                            color: (settings.showRhymes && !settings.focusMode) ? Colors.transparent : textStyle.color,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Write your song lyrics here...',
                            hintStyle: textStyle.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          cursorColor: colorScheme.primary,
                          selectionControls: materialTextSelectionControls,
                          enableInteractiveSelection: true,
                          contextMenuBuilder: (context, editableTextState) {
                            return AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            );
                          },
                          strutStyle: StrutStyle(
                            fontSize: textStyle.fontSize,
                            height: textStyle.height,
                            forceStrutHeight: true,
                          ),
                        ),
                        
                        // Rhyme coloring overlay (pointer events disabled)
                        if (_controller.text.isNotEmpty && settings.showRhymes && !settings.focusMode)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _shimmerAnimation,
                                builder: (context, child) {
                                  return RichText(
                                    text: _buildColoredTextSpan(_controller.text, textStyle),
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    textScaler: MediaQuery.textScalerOf(context),
                                    strutStyle: StrutStyle(
                                      fontSize: textStyle.fontSize,
                                      height: textStyle.height,
                                      forceStrutHeight: true,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (settings.showSyllables && !settings.focusMode)
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
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (success) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    color: colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    success ? 'Words saved ✨' : message,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: success
                ? colorScheme.primary
                : colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
    _selectionTimer?.cancel();
    _shimmerController.dispose();
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
    for (int i = 0; i < lineOffsets.length && i < syllableCounts.length; i++) {
      final lineInfo = lineOffsets[i];
      final offsetY = lineInfo['offset'] as double;
      final height = lineInfo['height'] as double;

      // Draw subtle glow for current line (not a solid block)
      if (i == currentLine) {
        // Create a soft glow effect with gradient
        final glowRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(-10, offsetY - 2, size.width + 20, height + 4),
          const Radius.circular(12),
        );

        final glowPaint = Paint()
          ..shader = RadialGradient(
            center: Alignment.centerLeft,
            radius: 1.5,
            colors: [
              highlightColor.withValues(alpha: 0.15),
              highlightColor.withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(glowRect.outerRect);

        canvas.drawRRect(glowRect, glowPaint);
      }

      // Draw visual dots for syllable count
      final syllableCount = syllableCounts[i];
      final isActive = i == currentLine;
      final dotColor = isActive ? activeTextColor : inactiveTextColor;

      // Use dots for counts up to 12, otherwise show number
      if (syllableCount <= 12) {
        final dotSize = 4.0;
        final dotSpacing = 6.0;
        final totalWidth = (syllableCount * dotSize) + ((syllableCount - 1) * (dotSpacing - dotSize));

        final startX = size.width - totalWidth - 24;
        final centerY = offsetY + (height / 2);

        final dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

        // Draw dots
        for (int j = 0; j < syllableCount; j++) {
          final dotX = startX + (j * dotSpacing);
          canvas.drawCircle(
            Offset(dotX, centerY),
            isActive ? dotSize / 2 : dotSize / 2.5,
            dotPaint,
          );
        }
      } else {
        // For longer lines, show number instead
        final textSpan = TextSpan(
          text: '$syllableCount',
          style: textStyle.copyWith(
            color: dotColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
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
  }

  @override
  bool shouldRepaint(covariant _SyllableCountPainter oldDelegate) {
    return oldDelegate.lineOffsets != lineOffsets ||
        oldDelegate.syllableCounts != syllableCounts ||
        oldDelegate.currentLine != currentLine;
  }
}
