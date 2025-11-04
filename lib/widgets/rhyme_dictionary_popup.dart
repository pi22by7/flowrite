import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/rhyme_dictionary_service.dart';
import '../utils/animations.dart';

class RhymeDictionaryPopup extends StatefulWidget {
  final String selectedText;
  final Offset position;
  final VoidCallback onClose;
  final Function(String) onWordTap;

  const RhymeDictionaryPopup({
    super.key,
    required this.selectedText,
    required this.position,
    required this.onClose,
    required this.onWordTap,
  });

  @override
  State<RhymeDictionaryPopup> createState() => _RhymeDictionaryPopupState();
}

class _RhymeDictionaryPopupState extends State<RhymeDictionaryPopup>
    with SingleTickerProviderStateMixin {
  final RhymeDictionaryService _rhymeService = RhymeDictionaryService();
  List<RhymeResult> _perfectRhymes = [];
  List<RhymeResult> _nearRhymes = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // Use organic motion for beautiful unfold animation
    _animationController = AnimationController(
      duration: FlowriteDurations.emphasized,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: FlowriteCurves.organicMotion,
    ));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: FlowriteCurves.gentleReveal,
    ));

    _animationController.forward();
    _loadRhymes();
  }

  @override
  void didUpdateWidget(RhymeDictionaryPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If selected text changed, reload rhymes
    if (oldWidget.selectedText != widget.selectedText) {
      debugPrint('🔄 Selected text changed from "${oldWidget.selectedText}" to "${widget.selectedText}" - reloading rhymes');
      _loadRhymes();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rhymeService.dispose();
    super.dispose();
  }

  Future<void> _loadRhymes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final words = widget.selectedText
          .toLowerCase()
          .split(RegExp(r'[^a-zA-Z]+'))
          .where((word) => word.isNotEmpty)
          .toList();

      if (words.length == 1) {
        // Single word - get all rhymes and separate by score
        final allRhymes = await _rhymeService.getRhymes(words.first);
        
        // Separate into perfect and near rhymes based on score
        _perfectRhymes = allRhymes.where((rhyme) => rhyme.score >= 180).toList();
        _nearRhymes = allRhymes.where((rhyme) => rhyme.score < 180 && rhyme.score >= 100).toList();
      } else if (words.length > 1) {
        // Multiple words - get slant rhymes (placeholder implementation)
        _nearRhymes = await _rhymeService.findSlantRhymes(words);
        _perfectRhymes = [];
      }
    } catch (e) {
      // Handle errors gracefully
      _perfectRhymes = [];
      _nearRhymes = [];
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onRhymeWordTap(String word) {
    HapticFeedback.lightImpact();
    widget.onWordTap(word);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx,
          top: widget.position.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    minWidth: 280,
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                    minHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 20,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rhyme Dictionary',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'for "${widget.selectedText}"',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(40, 40),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Flexible(
                        child: _isLoading
                            ? _buildLoadingState(colorScheme)
                            : _buildRhymesList(theme, colorScheme),
                      ),
                      
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finding rhymes...',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRhymesList(ThemeData theme, ColorScheme colorScheme) {
    final hasResults = _perfectRhymes.isNotEmpty || _nearRhymes.isNotEmpty;
    
    if (!hasResults) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 32,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No rhymes found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_perfectRhymes.isNotEmpty) ...[
            _buildRhymeSection(
              'True Echoes',
              'Perfect matches that sing together',
              _perfectRhymes,
              theme,
              colorScheme,
              Icons.music_note_rounded,
            ),
            if (_nearRhymes.isNotEmpty) const SizedBox(height: 12),
          ],
          if (_nearRhymes.isNotEmpty)
            _buildRhymeSection(
              widget.selectedText.split(RegExp(r'[^a-zA-Z]+')).length > 1
                  ? 'Close Harmonies'
                  : 'Gentle Echoes',
              widget.selectedText.split(RegExp(r'[^a-zA-Z]+')).length > 1
                  ? 'Words that dance around each other'
                  : 'Near matches with subtle charm',
              _nearRhymes,
              theme,
              colorScheme,
              Icons.blur_circular_rounded,
            ),
        ],
      ),
    );
  }

  Widget _buildRhymeSection(
    String title,
    String description,
    List<RhymeResult> rhymes,
    ThemeData theme,
    ColorScheme colorScheme,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Spectral',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: rhymes.asMap().entries.map((entry) {
              final index = entry.key;
              final rhyme = entry.value;
              // Stagger the animation for each chip
              final delay = Duration(milliseconds: 50 + (index * 30));
              return TweenAnimationBuilder<double>(
                duration: FlowriteDurations.standard,
                curve: FlowriteCurves.organicMotion,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  // Delay the animation
                  final delayedValue = (value - (delay.inMilliseconds / FlowriteDurations.standard.inMilliseconds)).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: delayedValue,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - delayedValue)),
                      child: child,
                    ),
                  );
                },
                child: _buildRhymeChip(rhyme, theme, colorScheme),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRhymeChip(
    RhymeResult rhyme,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onRhymeWordTap(rhyme.word),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rhyme.word,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              if (rhyme.syllables > 0) ...[
                const SizedBox(width: 8),
                // Visual syllable dots (use dots for ≤8, numbers for >8)
                if (rhyme.syllables <= 8)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      rhyme.syllables,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          left: index > 0 ? 3 : 0,
                        ),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${rhyme.syllables}',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}