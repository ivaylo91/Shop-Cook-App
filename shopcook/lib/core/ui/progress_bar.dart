import 'package:flutter/material.dart';

import '../design.dart';
import '../localization.dart';

/// An animated progress track, rounded at both ends.
///
/// Animates from wherever it was to wherever it is, so ticking an item reads
/// as the bar advancing rather than as a new bar appearing.
class AppProgressBar extends StatelessWidget {
  final int done;
  final int total;
  final double height;
  final Color? color;

  const AppProgressBar({
    super.key,
    required this.done,
    required this.total,
    this.height = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.accent;
    final fraction = total == 0 ? 0.0 : done / total;

    return Semantics(
      label: context.l10n.progressPickedUp(done, total),
      value: '${(fraction * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: Motion.slow,
        curve: Motion.enter,
        builder: (context, value, _) => ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: tint.withValues(alpha: palette.isDark ? 0.18 : 0.12),
            valueColor: AlwaysStoppedAnimation(tint),
          ),
        ),
      ),
    );
  }
}
