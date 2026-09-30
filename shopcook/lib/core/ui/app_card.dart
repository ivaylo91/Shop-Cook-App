import 'package:flutter/material.dart';

import '../design.dart';

/// A raised surface on the app's ground.
///
/// Not everything should be a card — this is for a group of related rows or
/// one self-contained block. [tint] colours the shadow so a card under an
/// aisle heading feels attached to it; the shadow resolves through the
/// palette, which drops the tint in dark mode where it would read as a glow.
///
/// A card that can be tapped gives slightly while it is pressed, so the
/// surface answers the finger before the tap has done anything.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  /// How far a pressed card gives. Subtle on purpose: it should be felt
  /// more than seen.
  static const _pressedScale = 0.97;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Radii.card);
    final tappable = widget.onTap != null || widget.onLongPress != null;

    Widget content = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: widget.child,
    );

    if (tappable) {
      content = InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        // The ink's own idea of "pressed", which already waits out the
        // start of a scroll — so dragging the list does not dent the cards
        // under the finger.
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        borderRadius: radius,
        child: content,
      );
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: palette.shadow(
          widget.tint ?? palette.accent,
          opacity: widget.shadowOpacity,
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

    if (!tappable || context.reduceMotion) return card;

    return AnimatedScale(
      scale: _pressed ? _pressedScale : 1,
      duration: Motion.fast,
      curve: Motion.enter,
      child: card,
    );
  }
}

/// Rows stacked into one card, hairline-separated, so a list has rhythm
/// instead of reading as a stack of floating tiles.
///
/// When rows come and go — an item added, or ticked in shopping mode and so
/// moved to the basket — the card resizes rather than snapping, and a row
/// that arrives fades in. That bridges what would otherwise be a teleport.
/// Rows present when the card first appears do not animate: a screen that
/// fades every row in on every visit is slower, not nicer. Only keyed
/// children can be told apart, so only they fade.
class AppCardList extends StatefulWidget {
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
  State<AppCardList> createState() => _AppCardListState();
}

class _AppCardListState extends State<AppCardList> {
  Set<Key> _known = const {};
  Set<Key> _arrived = const {};

  @override
  void initState() {
    super.initState();
    // Read now rather than lazily: the rows here at the start are the ones
    // that must not count as arriving.
    _known = _keysOf(widget.children);
  }

  static Set<Key> _keysOf(List<Widget> children) => {
    for (final child in children)
      if (child.key != null) child.key!,
  };

  @override
  void didUpdateWidget(AppCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = _keysOf(widget.children);
    _arrived = keys.difference(_known);
    _known = keys;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final children = widget.children;

    final rows = Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: widget.dividerIndent,
              color: palette.divider,
            ),
          if (children[i].key case final key?)
            _FadeIn(
              key: key,
              animate: _arrived.contains(key),
              child: children[i],
            )
          else
            children[i],
        ],
      ],
    );

    return AppCard(
      padding: null,
      tint: widget.tint,
      shadowOpacity: 0.08,
      // Resizing is movement, so it goes when the phone asks for less; the
      // rows' fade stays. Left out rather than given a zero duration, which
      // AnimatedSize cannot lay out.
      child: context.reduceMotion
          ? rows
          : AnimatedSize(
              duration: Motion.base,
              curve: Motion.enter,
              alignment: Alignment.topCenter,
              child: rows,
            ),
    );
  }
}

/// Fades its child in once, when it is first built, if asked to.
class _FadeIn extends StatefulWidget {
  final bool animate;
  final Widget child;

  const _FadeIn({super.key, required this.animate, required this.child});

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> {
  // Decided once: later rebuilds must not restart the fade.
  late final double _from = widget.animate ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: 1),
      duration: Motion.fast,
      curve: Motion.enter,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: widget.child,
    );
  }
}
