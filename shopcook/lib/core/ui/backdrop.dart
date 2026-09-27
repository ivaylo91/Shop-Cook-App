import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../design.dart';

/// The ground behind a screen: the plain surface with a faint, scattered
/// pattern of groceries and kitchen things drawn over it.
///
/// Wraps a [Scaffold] whose own background is transparent, so the pattern
/// shows in the gaps between cards and behind empty states. The backdrop is
/// part of each page rather than of the whole app because a page has to be
/// opaque: with one shared pattern behind transparent pages, the page being
/// left would show through the one arriving during every transition.
///
/// Drawn from the icon font the app already uses, so it costs no image
/// assets, stays sharp at any density, and follows the theme — the tint is
/// the accent at a few percent, enough to give the ground some life while
/// staying well behind text.
class Backdrop extends StatelessWidget {
  final Widget child;

  /// How strongly the pattern shows. 1 is the quiet default for working
  /// screens; the sign-in screens, which have little else on them, use more.
  final double intensity;

  const Backdrop({super.key, required this.child, this.intensity = 1});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final alpha = (palette.isDark ? 0.07 : 0.065) * intensity;

    return ColoredBox(
      color: palette.surface,
      child: CustomPaint(
        painter: _DoodlePainter(palette.accent.withValues(alpha: alpha)),
        // Its own layer, so scrolling a list repaints the list and not the
        // few hundred glyphs behind it.
        child: RepaintBoundary(child: child),
      ),
    );
  }
}

/// One doodle in the tile: which icon, where (as a fraction of the tile),
/// how big, and how far it is turned.
typedef _Doodle = ({
  FaIconData icon,
  double x,
  double y,
  double size,
  double turn,
});

class _DoodlePainter extends CustomPainter {
  final Color color;

  _DoodlePainter(this.color);

  /// One tile of the pattern, repeated across the screen with every other
  /// row shifted by half a tile so the repeat does not read as a grid.
  /// Placed by hand rather than randomly, so nothing overlaps and the gaps
  /// look even.
  static const _tile = 200.0;
  static const List<_Doodle> _doodles = [
    (icon: FontAwesomeIcons.carrot, x: 0.10, y: 0.12, size: 26, turn: -0.35),
    (icon: FontAwesomeIcons.lemon, x: 0.55, y: 0.06, size: 22, turn: 0.25),
    (icon: FontAwesomeIcons.fish, x: 0.84, y: 0.30, size: 24, turn: -0.15),
    (icon: FontAwesomeIcons.breadSlice, x: 0.34, y: 0.36, size: 22, turn: 0.2),
    (icon: FontAwesomeIcons.appleWhole, x: 0.06, y: 0.58, size: 22, turn: 0.1),
    (icon: FontAwesomeIcons.pepperHot, x: 0.62, y: 0.52, size: 22, turn: 0.6),
    (icon: FontAwesomeIcons.egg, x: 0.90, y: 0.74, size: 18, turn: -0.3),
    (icon: FontAwesomeIcons.cheese, x: 0.30, y: 0.80, size: 22, turn: -0.12),
    (
      icon: FontAwesomeIcons.basketShopping,
      x: 0.62,
      y: 0.88,
      size: 22,
      turn: 0.08,
    ),
    (icon: FontAwesomeIcons.seedling, x: 0.02, y: 0.94, size: 18, turn: 0.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final glyphs = {for (final doodle in _doodles) doodle.icon: _glyph(doodle)};

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var row = -1; row * _tile < size.height + _tile; row++) {
      final shift = row.isOdd ? _tile / 2 : 0.0;
      for (var col = -1; col * _tile < size.width + _tile; col++) {
        final origin = Offset(col * _tile + shift, row * _tile);
        for (final doodle in _doodles) {
          final glyph = glyphs[doodle.icon]!;
          canvas.save();
          canvas.translate(
            origin.dx + doodle.x * _tile,
            origin.dy + doodle.y * _tile,
          );
          canvas.rotate(doodle.turn);
          glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
          canvas.restore();
        }
      }
    }
    canvas.restore();
  }

  TextPainter _glyph(_Doodle doodle) => TextPainter(
    text: TextSpan(
      text: String.fromCharCode(doodle.icon.codePoint),
      style: TextStyle(
        fontFamily: doodle.icon.fontFamily,
        package: doodle.icon.fontPackage,
        fontSize: doodle.size,
        color: color,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_DoodlePainter old) => old.color != color;
}
