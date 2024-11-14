// lib/widgets/settings_panel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.settings, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Editor Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _buildSection(
            title: 'Font Family',
            child: SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: settings.availableFonts.length,
                itemBuilder: (context, index) {
                  final font = settings.availableFonts[index];
                  final isSelected = font == settings.fontFamily;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        font,
                        style: TextStyle(
                          fontFamily: font,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) settings.setFontFamily(font);
                      },
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.primary,
                    ),
                  );
                },
              ),
            ),
          ),
          _buildSection(
            title: 'Font Size',
            child: Slider(
              value: settings.fontSize,
              min: 14,
              max: 24,
              divisions: 10,
              label: '${settings.fontSize.round()}',
              onChanged: (value) => settings.setFontSize(value),
            ),
          ),
          _buildSection(
            title: 'Line Height',
            child: Slider(
              value: settings.lineHeight,
              min: 1.0,
              max: 2.0,
              divisions: 20,
              label: settings.lineHeight.toStringAsFixed(1),
              onChanged: (value) => settings.setLineHeight(value),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Preview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(
              'The quick brown fox jumps over the lazy dog',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
