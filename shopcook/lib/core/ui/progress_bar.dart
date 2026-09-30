import 'package:flutter/material.dart';

import '../design.dart';
import '../localization.dart';

/// An animated progress track, rounded at both ends.
///
/// Animates from wherever it was to wherever it is, so ticking an item reads
/// as the bar advancing rather than as a new bar appearing. It is drawn at
/// its value the first time: a list screen is opened many times a day, and
/// every bar filling from empty each time would be motion with nothing to
/// say.
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
        // No begin: the first build starts at the value itself.
        tween: Tween(end: fraction),
        duration: context.reduceMotion ? Duration.zero : Motion.base,
        curve: Motion.enter,
        builder: (context, value, _) => ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: tint.withValues(
              alpha: palette.isDark ? 0.18 : 0.12,
            ),
            valueColor: AlwaysStoppedAnimation(tint),
          ),
        ),
      ),
    );
  }
}
