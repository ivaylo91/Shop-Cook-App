import 'package:flutter/material.dart';

import '../design.dart';

/// Empty states are an opportunity: say what goes here and how to get there.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// The way out. An empty state without one is a dead end.
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.xl),
              decoration: BoxDecoration(
                color: palette.accent.withValues(
                  alpha: palette.isDark ? 0.16 : 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: palette.accent),
            ),
            const SizedBox(height: Insets.xl),
            Text(
              title,
              style: AppText.title.copyWith(color: palette.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.sm),
            ConstrainedBox(
              // Keep the explanation to a readable measure on a tablet.
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: palette.inkMuted),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Insets.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What a failed stream or request looks like.
///
/// Never shows the exception: `Error: $e` in front of a user is a bug, not an
/// error message. [details] is there for the cases where a caller has
/// something specific and useful to say.
class ErrorState extends StatelessWidget {
  final String title;
  final String? details;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final error = Theme.of(context).colorScheme.error;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 26, color: error),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              title,
              style: AppText.title.copyWith(color: palette.ink),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: Insets.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: palette.inkMuted),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: Insets.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact inline note, for a section that has something to explain rather
/// than a whole screen that failed.
class InlineNote extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const InlineNote({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.inkMuted;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(color: palette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
