// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../services/cloud_sync_service.dart';
import '../widgets/file_dialog.dart';
import '../widgets/settings_panel.dart';
import '../widgets/sync_status.dart';
import 'editor_screen.dart';
import '../models/writing_file.dart';
import '../services/file_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FileService _fileService = FileService();
  final CloudSyncService _cloudSync = CloudSyncService();
  List<WritingFile> _files = [];
  StreamSubscription? _cloudSubscription;
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cloudSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadFiles();
      _setupCloudSync();
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _fileService.getFiles(context);
      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  void _setupCloudSync() {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    syncProvider.authStateChanges.listen((user) {
      if (user != null) {
        _cloudSubscription?.cancel();
        _cloudSubscription = _cloudSync.getFilesStream().listen((cloudFiles) {
          setState(() {
            _files = cloudFiles;
          });
        });
      } else {
        _cloudSubscription?.cancel();
        _loadFiles();
      }
    });
  }

  void _manualSync() async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      // Always refresh local files first
      await _loadFiles();

      // Only sync to cloud if signed in
      if (syncProvider.isSignedIn) {
        debugPrint('User is signed in, syncing pending changes');
        await syncProvider.checkPendingSyncs();
        // Reload files after cloud sync
        await _loadFiles();

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Files synced successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        debugPrint('User not signed in, local sync only');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Local files refreshed (sign in for cloud sync)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during manual sync: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error syncing files: $e'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalAppBar(themeProvider, colorScheme),
            Expanded(
              child: _files.isEmpty
                  ? _buildMinimalEmptyState(colorScheme)
                  : _buildFilesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildMinimalFAB(colorScheme),
    );
  }

  Widget _buildMinimalAppBar(
      ThemeProvider themeProvider, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flowrite',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _files.isEmpty
                      ? 'Start writing'
                      : '${_files.length} ${_files.length == 1 ? 'song' : 'songs'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SyncStatus(),
              const SizedBox(width: 8),
              _buildIconButton(
                Icons.sync_rounded,
                colorScheme,
                _manualSync,
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                themeProvider.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                colorScheme,
                () => themeProvider.toggleTheme(),
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                Icons.settings_rounded,
                colorScheme,
                () => _showSettings(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      IconData icon, ColorScheme colorScheme, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
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
            icon,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.edit_note_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No songs yet',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first song',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: _files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildMinimalFileCard(_files[index]),
    );
  }

  Widget _buildMinimalFileCard(WritingFile file) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openFile(file),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to edit',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: colorScheme.onSurface),
                        const SizedBox(width: 12),
                        Text('Rename',
                            style: TextStyle(color: colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Text('Delete',
                            style: TextStyle(color: colorScheme.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _handleMenuAction(value, file),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalFAB(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _createNewFile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: colorScheme.onPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'New Song',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onPrimary,
                    letterSpacing: 0.2,
                  ),
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

  void _handleMenuAction(String action, WritingFile file) {
    switch (action) {
      case 'rename':
        _renameFile(file);
        break;
      case 'delete':
        _deleteFile(file);
        break;
    }
  }

  void _openFile(WritingFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(file: file),
      ),
    );
  }

  void _renameFile(WritingFile file) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => FileDialog(
        initialName: file.name,
        title: 'Rename Song',
        isRename: true,
      ),
    );

    if (name != null && name.isNotEmpty && name != file.name) {
      await _fileService.renameFile(file, name);
      _loadFiles();
    }
  }

  void _createNewFile() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const FileDialog(
        initialName: '',
        title: 'New Song',
        isRename: false,
      ),
    );

    if (name != null && name.isNotEmpty) {
      final file = await _fileService.createFile(name);
      setState(() {
        _files.add(file);
      });
    }
  }

  Future<void> _deleteFile(WritingFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _fileService.deleteFile(file);
      setState(() {
        _files.remove(file);
      });
    }
  }
}
