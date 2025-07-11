// lib/widgets/sync_status.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';

class SyncStatus extends StatelessWidget {
  const SyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Stack(
        children: [
          Icon(
            syncProvider.isSignedIn ? Icons.cloud_done : Icons.cloud_off,
            color: colorScheme.primary,
          ),
          if (syncProvider.isSyncing)
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
        ],
      ),
      onPressed: () => _showSyncDialog(context),
    );
  }

  // Fix for _showSyncDialog in SyncStatus
  void _showSyncDialog(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final navigator = Navigator.of(context); // Store navigator reference

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          syncProvider.isSignedIn ? 'Cloud Sync' : 'Sign In',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (syncProvider.isSignedIn) ...[
              Text('Signed in as ${syncProvider.userEmail}'),
              const SizedBox(height: 16),
              Text(
                'Your files are automatically synced to the cloud.',
                style: TextStyle(color: colorScheme.onSurface.withAlpha(178)),
              ),
            ] else
              const Text(
                  'Sign in to enable cloud sync and access your files anywhere.'),
          ],
        ),
        actions: [
          if (syncProvider.isSignedIn)
            TextButton(
              onPressed: () async {
                await syncProvider.signOut();
                if (context.mounted) navigator.pop();
              },
              child: const Text('Sign Out'),
            )
          else
            FilledButton.icon(
              onPressed: () async {
                await syncProvider.signInWithGoogle();
                if (context.mounted) navigator.pop();
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
