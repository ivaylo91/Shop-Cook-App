import 'package:flutter/material.dart';

import '../design.dart';

/// A raised surface on the app's ground.
///
/// Not everything should be a card — this is for a group of related rows or
/// one self-contained block. [tint] colours the shadow so a card under an
/// aisle heading feels attached to it; the shadow resolves through the
/// palette, which drops the tint in dark mode where it would read as a glow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final double shadowOpacity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.xl),
    this.tint,
    this.shadowOpacity = 0.10,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Radii.card);

    Widget content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      content = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: palette.shadow(
          tint ?? palette.accent,
          opacity: shadowOpacity,
        ),
      ),
      // Clipped Material inside the shadow decoration rather than around it,
      // so ink ripples stay inside the rounded corners and the shadow is not
      // clipped away with them.
      child: ClipRRect(
        borderRadius: radius,
        child: Material(color: palette.card, child: content),
      ),
    );
  }
}

/// Rows stacked into one card, hairline-separated, so a list has rhythm
/// instead of reading as a stack of floating tiles.
class AppCardList extends StatelessWidget {
  final List<Widget> children;
  final Color? tint;

  /// Left inset for the separators, so they start after a leading control
  /// rather than cutting across it.
  final double dividerIndent;

  const AppCardList({
    super.key,
    required this.children,
    this.tint,
    this.dividerIndent = 64,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      padding: null,
      tint: tint,
      shadowOpacity: 0.08,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: dividerIndent,
                color: palette.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}
