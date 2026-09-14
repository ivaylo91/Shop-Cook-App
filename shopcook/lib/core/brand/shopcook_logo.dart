import 'package:flutter/material.dart';

import '../design.dart';

/// The ShopCook mark: a basket with steam rising from it, fusing the two
/// halves of the name into one silhouette.
///
/// Drawn as a vector rather than shipped as a bitmap so it stays sharp at
/// any size and can take its colour from the theme. All geometry is
/// expressed in a 100×100 box and scaled, so the proportions hold whether
/// it renders at 24px in an app bar or 96px on the login screen.
class ShopCookLogo extends StatelessWidget {
  final double size;

  /// Defaults to the theme's accent, resolved at build rather than baked in
  /// as a constant, so the mark lightens with the palette in dark mode.
  final Color? color;

  const ShopCookLogo({super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShopCookLogoPainter(color ?? context.palette.accent),
        isComplex: false,
      ),
    );
  }
}

/// The mark inside a rounded badge, for places that need a contained icon
/// such as the login header or an about screen.
class ShopCookLogoBadge extends StatelessWidget {
  final double size;
  final Color? color;

  const ShopCookLogoBadge({super.key, this.size = 56, this.color});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.accent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: palette.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(child: ShopCookLogo(size: size * 0.62, color: tint)),
    );
  }
}

class _ShopCookLogoPainter extends CustomPainter {
  final Color color;

  _ShopCookLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;

    // Steam sits behind the basket and is lighter, so the basket stays the
    // shape the eye locks onto at small sizes.
    final steam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * s
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.45);

    canvas.drawPath(_steamCurl(s, 38), steam);
    canvas.drawPath(_steamCurl(s, 62), steam);

    final basket = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    // Rim and body are separate shapes with a gap between them, rather than
    // one slab with a cut-out: no blend modes, so it composites correctly
    // on any background.
    canvas.drawRRect(
      RRect.fromLTRBR(
        14 * s,
        44 * s,
        86 * s,
        55 * s,
        Radius.circular(5.5 * s),
      ),
      basket,
    );
    canvas.drawPath(_basket(s), basket);
  }

  /// One S-shaped wisp rising from behind the basket rim.
  Path _steamCurl(double s, double x) {
    return Path()
      ..moveTo(x * s, 42 * s)
      ..cubicTo(
        (x - 9) * s,
        33 * s,
        (x + 9) * s,
        27 * s,
        x * s,
        16 * s,
      );
  }

  /// The basket body below the rim: tapered sides, softly rounded base, and
  /// weave slots punched through it.
  ///
  /// The slots are subtracted from the path rather than painted in a
  /// background colour, so the mark drops onto any surface. Without them the
  /// silhouette reads as a soup bowl, which loses the "shop" half of the name.
  Path _basket(double s) {
    final body = Path()
      ..moveTo(20 * s, 60 * s)
      ..lineTo(80 * s, 60 * s)
      ..lineTo(72 * s, 79 * s)
      ..quadraticBezierTo(70 * s, 86 * s, 63 * s, 86 * s)
      ..lineTo(37 * s, 86 * s)
      ..quadraticBezierTo(30 * s, 86 * s, 28 * s, 79 * s)
      ..close();

    // Kept deliberately chunky so they survive at app-bar sizes.
    final slots = Path();
    for (final x in <double>[41, 59]) {
      slots.addRRect(
        RRect.fromLTRBR(
          // Taller than wide, so they read as woven slots rather than holes.
          (x - 3.5) * s,
          64 * s,
          (x + 3.5) * s,
          79 * s,
          Radius.circular(3 * s),
        ),
      );
    }

    return Path.combine(PathOperation.difference, body, slots);
  }

  @override
  bool shouldRepaint(_ShopCookLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
