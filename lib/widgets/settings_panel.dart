import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../services/webdav_config_service.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _isMigrating = false;
  bool _isTestingWebDav = false;
  bool _isSavingWebDav = false;
  final _webDavConfigService = WebDavConfigService();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _appPasswordController = TextEditingController();
  bool _webDavFormLoaded = false;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _appPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadWebDavForm() async {
    if (_webDavFormLoaded) return;
    _webDavFormLoaded = true;
    final config = await _webDavConfigService.getConfig();
    if (config == null || !mounted) return;
    _serverUrlController.text = config.serverUrl;
    _usernameController.text = config.username;
    _appPasswordController.text = config.appPassword;
    setState(() {});
  }

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
          // Atmospheric header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 24,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Your Atmosphere',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Spectral',
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    'Shape your creative sanctuary',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Ambiance Section
          _buildAmbianceSection(context, settings, colorScheme),

          // Typography group header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Icon(
                  Icons.text_fields_rounded,
                  size: 20,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Typography',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                ),
              ],
            ),
          ),

          // Font Family Section
          _buildMinimalSection(
            context,
            title: 'Voice & Character',
            description: 'Choose the personality of your words',
            child: _buildFontSelector(settings, colorScheme),
          ),

          // Font Size Section
          _buildMinimalSection(
            context,
            title: 'Text Scale',
            description: 'Find your comfortable reading size',
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
            title: 'Breathing Room',
            description: 'Space between lines for clarity',
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
            title: 'How It Feels',
            icon: Icons.visibility_outlined,
            description: 'See your choices come to life',
            child: _buildPreview(settings, colorScheme),
          ),

          // Features Section
          _buildMinimalSection(
            context,
            title: 'Writing Tools',
            icon: Icons.tune_rounded,
            description: 'Helpers for your creative flow',
            child: _buildFeatures(settings, colorScheme),
          ),

          // Storage Section
          _buildMinimalSection(
            context,
            title: 'Storage & Export',
            icon: Icons.folder_outlined,
            description: 'Where your words live, and how to take them with you',
            child: _buildStorageSection(context, settings, colorScheme),
          ),

          // Cloud Sync Section
          _buildMinimalSection(
            context,
            title: 'Cloud Sync',
            icon: Icons.cloud_sync_outlined,
            description: 'Keep your words backed up and in sync everywhere',
            child: _buildCloudSyncSection(context, colorScheme),
          ),

          // Focus Mode Section
          _buildMinimalSection(
            context,
            title: 'Pure Focus',
            icon: Icons.center_focus_strong_rounded,
            description: 'Hide all distractions, just you and your words',
            child: _buildFocusMode(settings, colorScheme),
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
    IconData? icon,
    String? description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: colorScheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            )
          else
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: icon != null ? 26 : 0),
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildFontSelector(
      SettingsProvider settings, ColorScheme colorScheme) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: settings.availableFonts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final font = settings.availableFonts[index];
          final isSelected = font == settings.fontFamily;
          final personality = settings.fontPersonalities[font] ?? '';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => settings.setFontFamily(font),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.4)
                        : colorScheme.outline.withValues(alpha: 0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Font personality label
                    if (personality.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.outline.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          personality,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.5),
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),

                    const SizedBox(height: 8),

                    // Font preview
                    Text(
                      'Words flow',
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Font name
                    Text(
                      font,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
              title: 'Show Syllable Count',
              subtitle: 'Display syllable counts for each line',
              value: settings.showSyllables,
              onChanged: (value) => settings.setShowSyllables(value),
              colorScheme: colorScheme,
            ),
            if (settings.showSyllables) ...[
              const SizedBox(height: 12),
              _buildMinimalSwitch(
                title: 'Dot Pattern Syllable Counter',
                subtitle: 'Show counts as dot shapes instead of numbers',
                value: settings.syllableDotPattern,
                onChanged: (value) => settings.setSyllableDotPattern(value),
                colorScheme: colorScheme,
              ),
            ],
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

  Widget _buildStorageSection(
    BuildContext context,
    SettingsProvider settings,
    ColorScheme colorScheme,
  ) {
    final currentPath = settings.customSavePath.isEmpty
        ? 'Default app storage'
        : settings.customSavePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Location',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentPath,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _isMigrating ? null : () => _changeSaveLocation(context, settings),
                child: _isMigrating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change...'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _exportCurrentFiles(context, all: false),
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Export Current'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _exportCurrentFiles(context, all: true),
                icon: const Icon(Icons.archive_outlined, size: 16),
                label: const Text('Export All'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _changeSaveLocation(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final selectedPath = await FilePicker.platform.getDirectoryPath();
    if (selectedPath == null || !mounted) return;

    setState(() => _isMigrating = true);

    try {
      final storage = StorageService.create();
      if (storage is! FileSystemStorageService) {
        // Web has no filesystem to migrate; nothing to do.
        return;
      }

      final result = await storage.migrateStorageLocation(selectedPath);
      await settings.refreshCustomSavePath();

      if (!context.mounted) return;
      final message = result.success
          ? 'Moved ${result.migratedCount} file(s) to new location'
          : '${result.migratedCount} file(s) moved, ${result.failedIds.length} failed - old location kept as fallback';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to change save location: $e')));
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  Widget _buildCloudSyncSection(BuildContext context, ColorScheme colorScheme) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        final backendType = syncProvider.backendType;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: SyncBackendType.values
                  .where((t) => t != SyncBackendType.icloud) // Phase 4, not implemented yet
                  .map((type) {
                final isSelected = type == backendType;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          if (type == SyncBackendType.webdav) {
                            await _loadWebDavForm();
                            if (mounted) setState(() {});
                            return;
                          }
                          await syncProvider.switchBackend(type);
                          if (!context.mounted) return;
                          final settings = Provider.of<SettingsProvider>(context, listen: false);
                          await settings.setSyncBackendType(type);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.5)
                                  : colorScheme.outline.withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            _backendLabel(type),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (backendType == SyncBackendType.webdav || _webDavFormLoaded) ...[
              const SizedBox(height: 16),
              _buildWebDavForm(context, syncProvider, colorScheme),
            ],
          ],
        );
      },
    );
  }

  String _backendLabel(SyncBackendType type) {
    switch (type) {
      case SyncBackendType.none:
        return 'None';
      case SyncBackendType.supabase:
        return 'Supabase';
      case SyncBackendType.webdav:
        return 'WebDAV';
      case SyncBackendType.icloud:
        return 'iCloud';
    }
  }

  Widget _buildWebDavForm(
    BuildContext context,
    SyncProvider syncProvider,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NextCloud / ownCloud',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _serverUrlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://cloud.example.com/remote.php/dav/files/user/',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username', isDense: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'App Password', isDense: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isTestingWebDav ? null : () => _testWebDavConnection(context),
                  child: _isTestingWebDav
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test Connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSavingWebDav ? null : () => _saveWebDavConfig(context, syncProvider),
                  child: _isSavingWebDav
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save & Connect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  WebDavConfig _currentWebDavFormConfig() {
    return WebDavConfig(
      serverUrl: _serverUrlController.text.trim(),
      username: _usernameController.text.trim(),
      appPassword: _appPasswordController.text,
    );
  }

  Future<void> _testWebDavConnection(BuildContext context) async {
    setState(() => _isTestingWebDav = true);
    try {
      final success = await _webDavConfigService.testConnection(_currentWebDavFormConfig());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Connection successful' : 'Connection failed - check your details'),
      ));
    } finally {
      if (mounted) setState(() => _isTestingWebDav = false);
    }
  }

  Future<void> _saveWebDavConfig(BuildContext context, SyncProvider syncProvider) async {
    setState(() => _isSavingWebDav = true);
    try {
      final config = _currentWebDavFormConfig();
      await _webDavConfigService.saveConfig(config);
      await syncProvider.switchBackend(SyncBackendType.webdav);

      if (!context.mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.setSyncBackendType(SyncBackendType.webdav);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('WebDAV connected')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save WebDAV settings: $e')));
    } finally {
      if (mounted) setState(() => _isSavingWebDav = false);
    }
  }

  Future<void> _exportCurrentFiles(BuildContext context, {required bool all}) async {
    try {
      final fileService = FileService();
      final files = await fileService.getFiles(context);
      if (files.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No files to export')));
        return;
      }

      final exportService = ExportService();
      if (all) {
        await exportService.exportAll(files);
      } else {
        files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        await exportService.exportFile(files.first);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
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

  Widget _buildAmbianceSection(
    BuildContext context,
    SettingsProvider settings,
    ColorScheme colorScheme,
  ) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.wb_twilight_rounded,
                    size: 20,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ambiance',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                  ),
                ],
              ),
            ),

            // Theme mode
            _buildMinimalSection(
              context,
              title: 'Visual Theme',
              description: 'Choose light, dark, or follow the time of day',
              child: _buildThemeSelector(themeProvider, colorScheme),
            ),

            // Dynamic colors toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _buildMinimalSwitch(
                title: 'Material You Colors',
                subtitle: 'Adapt to your device wallpaper (Android 12+)',
                value: themeProvider.useDynamicColors,
                onChanged: (value) => themeProvider.toggleDynamicColors(),
                colorScheme: colorScheme,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeSelector(
    ThemeProvider themeProvider,
    ColorScheme colorScheme,
  ) {
    final themeOptions = [
      {'value': AppThemeMode.light, 'label': 'Light', 'icon': Icons.wb_sunny_rounded},
      {'value': AppThemeMode.dark, 'label': 'Dark', 'icon': Icons.nights_stay_rounded},
      {'value': AppThemeMode.system, 'label': 'System', 'icon': Icons.brightness_auto_rounded},
    ];

    return Row(
      children: themeOptions.map((option) {
        final isSelected = themeProvider.themeMode == option['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => themeProvider.setThemeMode(option['value'] as AppThemeMode),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.5)
                          : colorScheme.outline.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        size: 24,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFocusMode(SettingsProvider settings, ColorScheme colorScheme) {
    return _buildMinimalSwitch(
      title: 'Focus Mode',
      subtitle: 'Hides syllable counts, rhyme colors, and all UI distractions',
      value: settings.focusMode,
      onChanged: (value) => settings.setFocusMode(value),
      colorScheme: colorScheme,
    );
  }
}
