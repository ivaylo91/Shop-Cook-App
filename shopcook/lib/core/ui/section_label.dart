import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../design.dart';

/// A tinted section marker — recognisable by colour while scanning.
///
/// [color] defaults to the palette's muted ink, so a plain section ("Other
/// items") reads as quieter than a colour-coded one (an aisle).
class SectionLabel extends StatelessWidget {
  final FaIconData icon;
  final String label;

  /// How many items sit under this heading. Hidden when null, because "0" is
  /// noise on a section that only appears when it has contents.
  final int? count;
  final Color? color;

  /// An affordance at the end of the row — a collapse chevron, a "clear"
  /// button.
  final Widget? trailing;

  const SectionLabel({
    super.key,
    required this.icon,
    required this.label,
    this.count,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.inkMuted;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: palette.isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: FaIcon(icon, size: 16, color: tint),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Text(
            label,
            style: AppText.title.copyWith(color: tint),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: Insets.sm),
          Text(
            '$count',
            style: AppText.caption.copyWith(color: palette.inkFaint),
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: Insets.xs), trailing!],
      ],
    );
  }
}

/// A small count in a tinted pill, for places where the number is the point
/// — progress on a list card, items in a collapsed meal.
class CountPill extends StatelessWidget {
  final String label;
  final Color? color;

  const CountPill({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.accent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: palette.isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: tint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
