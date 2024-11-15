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

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _setupCloudSync();
  }


  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      ScaffoldMessenger.of(context);
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
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  void _setupCloudSync() {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // Listen to auth state changes
    syncProvider.authStateChanges.listen((user) {
      if (user != null) {
        // User signed in, start listening to cloud changes
        _cloudSubscription?.cancel();
        _cloudSubscription = _cloudSync.getFilesStream().listen((cloudFiles) {
          setState(() {
            _files = cloudFiles;
          });
        });
      } else {
        // User signed out, stop listening
        _cloudSubscription?.cancel();
        _loadFiles(); // Load local files only
      }
    });
  }

  void _manualSync() async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await Provider.of<SyncProvider>(context, listen: false).checkPendingSyncs();
      await _loadFiles();
    } catch (e) {
      debugPrint('Error during manual sync: $e');
      // Show error message to user
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error syncing files: $e')),
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
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: _buildAppBar(themeProvider, colorScheme),
      body: _files.isEmpty
          ? _buildEmptyState()
          : _buildGridView(context),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  AppBar _buildAppBar(ThemeProvider themeProvider, ColorScheme colorScheme) {
    return AppBar(
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text(
            'Flowrite',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        const SyncStatus(),
        IconButton(
          icon: Icon(Icons.sync, color: colorScheme.primary),
          onPressed: _manualSync,
        ),
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: colorScheme.primary,
          ),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        IconButton(
          icon: Icon(
            Icons.settings,
            color: colorScheme.primary,
          ),
          onPressed: () => _showSettings(context),
        ),
      ],
      elevation: 0,
      backgroundColor: Colors.transparent,
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

  Widget _buildGridView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _files.length,
            itemBuilder: (context, index) => _buildFileCard(_files[index]),
          ),
        );
      },
    );
  }

  int _calculateCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 2;
  }

  Widget _buildFileCard(WritingFile file) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFile(file),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(file, colorScheme),
            Expanded(
              child: _buildCardContent(file, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(WritingFile file, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            Icons.description_outlined,
            color: colorScheme.primary,
          ),
          _buildCardMenu(file, colorScheme),
        ],
      ),
    );
  }

  Widget _buildCardMenu(WritingFile file, ColorScheme colorScheme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: colorScheme.primary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => [
        _buildMenuItem(
          'rename',
          'Rename',
          Icons.edit,
          colorScheme.onSurface,
        ),
        _buildMenuItem(
          'delete',
          'Delete',
          Icons.delete_outline,
          colorScheme.error,
        ),
      ],
      onSelected: (value) => _handleMenuAction(value, file),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      String value,
      String text,
      IconData icon,
      Color color,
      ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(WritingFile file, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Tap to edit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_note_rounded,
              size: 80,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Notes Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Create your first note by tapping the button below',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _createNewFile,
      icon: const Icon(Icons.add),
      label: const Text('New Note'),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32)
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
        title: 'Rename Note',
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
        title: 'Create New Note',
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
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
