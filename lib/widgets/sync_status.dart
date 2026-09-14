import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../providers/settings_provider.dart';

class SyncStatus extends StatelessWidget {
  /// Opens the Settings panel (Cloud Sync section), used when the active
  /// backend needs credentials this widget doesn't collect itself.
  final VoidCallback onOpenSettings;

  const SyncStatus({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Nothing to show or manage when sync is turned off entirely.
    if (syncProvider.backendType == SyncBackendType.none) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Stack(
          children: [
            Icon(
              syncProvider.isCloudConfigured
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              size: 20,
            ),
            if (syncProvider.isSyncing)
              Positioned.fill(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
        onPressed: () => _showSyncDialog(context),
        iconSize: 20,
        padding: EdgeInsets.zero,
        splashRadius: 16,
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    switch (syncProvider.backendType) {
      case SyncBackendType.none:
        return; // Button isn't shown in this case; nothing to do.
      case SyncBackendType.supabase:
        _showSupabaseDialog(context, syncProvider);
      case SyncBackendType.webdav:
      case SyncBackendType.icloud:
        _showWebDavDialog(context, syncProvider);
    }
  }

  void _showSupabaseDialog(BuildContext context, SyncProvider syncProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final navigator = Navigator.of(context);
    final isSignedIn = syncProvider.isSignedIn;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        title: Text(
          isSignedIn ? 'Cloud Sync' : 'Sign In',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSignedIn) ...[
              Text(
                'Signed in as ${syncProvider.userEmail}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your files are automatically synced to the cloud.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ] else
              Text(
                'Sign in to enable cloud sync and access your files anywhere.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
        actions: [
          if (isSignedIn)
            _DialogButton(
              label: 'Sign Out',
              onPressed: () async {
                await syncProvider.signOut();
                if (context.mounted) navigator.pop();
              },
            )
          else
            _DialogButton(
              icon: Icons.login,
              label: 'Sign in with Google',
              onPressed: () async {
                await syncProvider.signInWithGoogle();
                if (context.mounted) navigator.pop();
              },
            ),
          const SizedBox(width: 8),
          _DialogButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showWebDavDialog(BuildContext context, SyncProvider syncProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final navigator = Navigator.of(context);
    final isConfigured = syncProvider.isCloudConfigured;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        title: Text(
          'WebDAV Sync',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          isConfigured
              ? 'Your files are automatically synced to your WebDAV server.'
              : 'Connect a WebDAV server (e.g. NextCloud/ownCloud) in Settings to enable sync.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          _DialogButton(
            icon: Icons.settings_outlined,
            label: isConfigured ? 'Manage in Settings' : 'Connect',
            onPressed: () {
              navigator.pop();
              onOpenSettings();
            },
          ),
          const SizedBox(width: 8),
          _DialogButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _DialogButton({required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        icon: icon != null
            ? Icon(icon, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.8))
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
