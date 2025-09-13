import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clean header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Editor Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),

          // Font Family Section
          _buildMinimalSection(
            context,
            title: 'Font Family',
            child: _buildFontSelector(settings, colorScheme),
          ),

          // Font Size Section
          _buildMinimalSection(
            context,
            title: 'Font Size',
            child: _buildSlider(
              value: settings.fontSize,
              min: 14,
              max: 24,
              divisions: 10,
              label: '${settings.fontSize.round()}pt',
              onChanged: (value) => settings.setFontSize(value),
              colorScheme: colorScheme,
              context: context,
            ),
          ),

          // Line Height Section
          _buildMinimalSection(
            context,
            title: 'Line Height',
            child: _buildSlider(
              value: settings.lineHeight,
              min: 1.0,
              max: 2.0,
              divisions: 20,
              label: settings.lineHeight.toStringAsFixed(1),
              onChanged: (value) => settings.setLineHeight(value),
              colorScheme: colorScheme,
              context: context,
            ),
          ),

          // Preview Section
          _buildMinimalSection(
            context,
            title: 'Preview',
            child: _buildPreview(settings, colorScheme),
          ),

          // Features Section
          _buildMinimalSection(
            context,
            title: 'Features',
            child: _buildFeatures(settings, colorScheme),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMinimalSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildFontSelector(
      SettingsProvider settings, ColorScheme colorScheme) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: settings.availableFonts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final font = settings.availableFonts[index];
          final isSelected = font == settings.fontFamily;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => settings.setFontFamily(font),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.3)
                        : colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  font,
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required Function(double) onChanged,
    required ColorScheme colorScheme,
    required BuildContext context,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              min.toStringAsFixed(min == min.toInt() ? 0 : 1),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Text(
              max.toStringAsFixed(max == max.toInt() ? 0 : 1),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.outline.withValues(alpha: 0.2),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withValues(alpha: 0.1),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(SettingsProvider settings, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sample Text',
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize,
              height: settings.lineHeight,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The quick brown fox jumps over the lazy dog.\nThis shows how your text will look in the editor.',
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize,
              height: settings.lineHeight,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(SettingsProvider settings, ColorScheme colorScheme) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          children: [
            _buildMinimalSwitch(
              title: 'Dynamic Colors',
              subtitle:
                  'Use Material You colors from your wallpaper (Android 12+)',
              value: themeProvider.useDynamicColors,
              onChanged: (value) => themeProvider.toggleDynamicColors(),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _buildMinimalSwitch(
              title: 'Show Syllable Count',
              subtitle: 'Display syllable counts for each line',
              value: settings.showSyllables,
              onChanged: (value) => settings.setShowSyllables(value),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _buildMinimalSwitch(
              title: 'Show Rhyme Colors',
              subtitle: 'Highlight rhyming words with colors',
              value: settings.showRhymes,
              onChanged: (value) => settings.setShowRhymes(value),
              colorScheme: colorScheme,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMinimalSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary;
              }
              return colorScheme.outline.withValues(alpha: 0.5);
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary.withValues(alpha: 0.3);
              }
              return colorScheme.outline.withValues(alpha: 0.1);
            }),
          ),
        ],
      ),
    );
  }
}
