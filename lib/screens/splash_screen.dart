import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  final String? loadingText;
  
  const SplashScreen({super.key, this.loadingText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo/flowrite_logo.png',
              height: 80,
              fit: BoxFit.fitHeight,
            ),
            const SizedBox(height: 48),
            
            // Linear progress indicator (more modern than circular)
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary, // Flow Teal
                ),
                minHeight: 3,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Loading text
            Text(
              loadingText ?? 'Loading...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}