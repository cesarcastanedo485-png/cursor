import 'package:flutter/material.dart';

/// Full-width error message with retry and optional secondary action (e.g. Open Settings).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.onSecondary,
    this.secondaryLabel,
  });

  final String message;
  /// Optional title; if null, defaults to "Something went wrong".
  final String? title;
  final VoidCallback? onRetry;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            title ?? 'Something went wrong',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (onRetry != null || onSecondary != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onSecondary != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: onSecondary,
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: Text(secondaryLabel ?? 'Settings'),
                    ),
                  ),
                if (onRetry != null)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
