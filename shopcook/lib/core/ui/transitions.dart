import 'package:flutter/material.dart';

import '../design.dart';

/// How one page replaces another: a fade with a slight rise.
///
/// Flutter's default on Android takes 450ms. Opening a list and going back
/// happens many times a day, and at that frequency a transition should be
/// felt as direction, not watched. So this is short, and the new page moves
/// only a little — enough to say "forward" without the wait.
class AppPageTransitions extends PageTransitionsBuilder {
  const AppPageTransitions();

  /// How far below its place a page starts, as a fraction of its height.
  static const _rise = 0.03;

  @override
  Duration get transitionDuration => Motion.base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _FadeRise(animation: animation, rise: _rise, child: child);
  }
}

class _FadeRise extends StatefulWidget {
  final Animation<double> animation;
  final double rise;
  final Widget child;

  const _FadeRise({
    required this.animation,
    required this.rise,
    required this.child,
  });

  @override
  State<_FadeRise> createState() => _FadeRiseState();
}

class _FadeRiseState extends State<_FadeRise> {
  /// The share of the transition the fade takes. A fade across the whole
  /// of it leaves two pages of text readable through each other for most of
  /// its length; kept this short, the new page is solid almost at once and
  /// the rise carries the rest.
  static const _fadeShare = 0.4;

  // Held here rather than made in build: each one listens to the route's
  // animation, and a new one per rebuild would never let go.
  late CurvedAnimation _move = _moveCurve();
  late CurvedAnimation _fade = _fadeCurve();

  // Flipped on the way out, so leaving also starts fast.
  CurvedAnimation _moveCurve() => CurvedAnimation(
    parent: widget.animation,
    curve: Motion.enter,
    reverseCurve: Motion.enter.flipped,
  );

  // In: opaque within the first part. Out: gone within the first part of
  // leaving, which is the top of the range since the value runs 1 → 0.
  CurvedAnimation _fadeCurve() => CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0, _fadeShare, curve: Motion.enter),
    reverseCurve: Interval(1 - _fadeShare, 1, curve: Motion.enter.flipped),
  );

  @override
  void didUpdateWidget(_FadeRise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _move.dispose();
      _fade.dispose();
      _move = _moveCurve();
      _fade = _fadeCurve();
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faded = FadeTransition(opacity: _fade, child: widget.child);
    if (context.reduceMotion) return faded;

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, widget.rise),
        end: Offset.zero,
      ).animate(_move),
      child: faded,
    );
  }
}

/// A dialog that arrives: it fades in while growing the last few percent
/// to full size, from the centre, and leaves faster than it came.
///
/// From the centre because a dialog belongs to the screen, not to whatever
/// was tapped to open it.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _AppDialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    ),
  );
}

class _AppDialogRoute<T> extends DialogRoute<T> {
  _AppDialogRoute({
    required super.context,
    required super.builder,
    super.barrierDismissible,
  }) : super(
         themes: InheritedTheme.capture(
           from: context,
           to: Navigator.of(context, rootNavigator: true).context,
         ),
         animationStyle: const AnimationStyle(duration: Motion.base),
       );

  static const _from = 0.95;

  CurvedAnimation? _curved;

  @override
  Duration get reverseTransitionDuration => Motion.fast;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_curved?.parent != animation) {
      _curved?.dispose();
      _curved = CurvedAnimation(
        parent: animation,
        curve: Motion.enter,
        reverseCurve: Motion.enter.flipped,
      );
    }
    final faded = FadeTransition(opacity: _curved!, child: child);
    if (context.reduceMotion) return faded;

    return ScaleTransition(
      scale: Tween<double>(begin: _from, end: 1).animate(_curved!),
      child: faded,
    );
  }

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }
}

/// How a bottom sheet moves: the iOS-style drawer curve, which starts fast
/// and takes its time settling, so the sheet feels pulled up rather than
/// pushed. Leaving is quicker than arriving. With motion reduced it simply
/// appears.
AnimationStyle sheetMotion(BuildContext context) => context.reduceMotion
    ? AnimationStyle.noAnimation
    : AnimationStyle(
        duration: Motion.sheet,
        reverseDuration: Motion.base,
        curve: Motion.drawer,
        reverseCurve: Motion.drawer.flipped,
      );
