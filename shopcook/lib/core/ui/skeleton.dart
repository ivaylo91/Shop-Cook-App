import 'package:flutter/material.dart';

import '../design.dart';
import 'app_card.dart';

/// A pulsing placeholder block.
///
/// Loading a list with skeleton rows rather than a centred spinner keeps the
/// layout still: the content lands where the placeholder already was, instead
/// of the whole screen jumping when the stream emits.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = Radii.chip,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Users who have asked the OS to reduce motion get the block without the
    // pulse, rather than no placeholder at all.
    if (MediaQuery.disableAnimationsOf(context)) {
      return _block(palette.sunken);
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: _block(palette.sunken),
    );
  }

  Widget _block(Color color) => Container(
    width: widget.width,
    height: widget.height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(widget.radius),
    ),
  );
}

/// Placeholder rows shaped like [ProductRow], for a list that is still
/// loading.
class SkeletonRows extends StatelessWidget {
  final int count;

  const SkeletonRows({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return AppCardList(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.md,
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 44,
                  child: Center(
                    child: Skeleton(width: 26, height: 26, radius: 999),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Uneven widths so it reads as text, not as a table.
                      Skeleton(width: i.isEven ? 150 : 110, height: 15),
                      const SizedBox(height: Insets.sm),
                      const Skeleton(width: 64, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
