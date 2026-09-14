import 'package:flutter/material.dart';

import '../features/shopping/product_category.dart';

/// Design tokens for ShopCook.
///
/// Spacing sits on an 8-point grid, the type scale is deliberately limited to
/// four sizes and two weights, and colour follows a 60/30/10 split: a neutral
/// base, dark text, and green reserved for actions and progress.
///
/// Colour lives in [AppPalette] rather than in static constants, because the
/// same roles have to resolve to different values in light and dark. Read it
/// as `context.palette`; the theme carries it as a [ThemeExtension] so a
/// widget never has to know which mode it is in.

abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const chip = 12.0;
  static const card = 20.0;
  static const pill = 999.0;
}

/// One vocabulary for movement, so a check-off on one screen feels like a
/// check-off on another.
///
/// [fast] is for state that should feel instant (a tick, a tint change),
/// [base] for anything that moves or resizes, and [slow] for a deliberate
/// moment the user is meant to notice.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 440);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// Slight overshoot, for the one thing per screen worth celebrating.
  static const emphasis = Curves.easeOutBack;
}

abstract final class AppText {
  /// Reserved for the one number that matters on a screen.
  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const body = TextStyle(fontSize: 15, height: 1.3);
  static const caption = TextStyle(fontSize: 13, height: 1.3);
}

/// The colour roles the app is built from, in one resolvable set.
///
/// Text colours are opaque rather than alpha-blended onto the ground. An
/// alpha value looks right on exactly one surface and drifts everywhere
/// else, and it cannot be checked for contrast without knowing what sits
/// behind it; these are picked to clear 4.5:1 on their own surface in both
/// modes.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Which mode this set belongs to. Aisle hues and shadows resolve from it.
  final Brightness brightness;

  /// 60% — the neutral ground everything sits on.
  final Color surface;
  final Color card;

  /// A recessed fill, for wells, skeletons and unfilled progress tracks.
  final Color sunken;

  /// 30% — text, at three levels of emphasis rather than three colours.
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  /// 10% — the accent, kept for actions, checks and progress.
  final Color accent;
  final Color onAccent;

  final Color divider;

  const AppPalette({
    required this.brightness,
    required this.surface,
    required this.card,
    required this.sunken,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.onAccent,
    required this.divider,
  });

  static const light = AppPalette(
    brightness: Brightness.light,
    surface: Color(0xFFF6F8F2),
    card: Color(0xFFFFFFFF),
    sunken: Color(0xFFEDF1E4),
    ink: Color(0xFF1A1C18),
    inkMuted: Color(0xFF5B6156),
    inkFaint: Color(0xFF6B7165),
    accent: Color(0xFF2E7D32),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFFE2E7D9),
  );

  /// Not an inversion of [light]: the ground is lifted off pure black so
  /// cards can sit above it, and the accent is lightened because #2E7D32 on
  /// a dark ground is too low-contrast to carry a label.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    surface: Color(0xFF121510),
    card: Color(0xFF1B1F19),
    sunken: Color(0xFF22271F),
    ink: Color(0xFFE9EDE2),
    inkMuted: Color(0xFFAFB7A8),
    inkFaint: Color(0xFF949C8C),
    accent: Color(0xFF86C888),
    onAccent: Color(0xFF0E2610),
    divider: Color(0xFF2F352C),
  );

  bool get isDark => brightness == Brightness.dark;

  /// One hue per aisle, so sections are recognisable at a glance while
  /// scanning. Used only as a tinted chip and icon, never as a large fill —
  /// nine saturated blocks would wreck the 60/30/10 balance.
  Color aisle(ProductCategory category) =>
      (isDark ? _aislesDark : _aislesLight)[category]!;

  /// Soft, tinted shadow. Never pure grey on a coloured ground — and never
  /// tinted at all in dark mode, where a coloured shadow reads as a glow.
  List<BoxShadow> shadow(Color tint, {double opacity = 0.10}) => [
    BoxShadow(
      color: isDark
          ? const Color(0xFF000000).withValues(alpha: opacity * 3.4)
          : tint.withValues(alpha: opacity),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? surface,
    Color? card,
    Color? sunken,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? accent,
    Color? onAccent,
    Color? divider,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      sunken: sunken ?? this.sunken,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      // Brightness has no midpoint; snap it so aisle hues and shadows never
      // resolve from a half-blended mode.
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

const Map<ProductCategory, Color> _aislesLight = {
  ProductCategory.produce: Color(0xFF4C8B2B),
  ProductCategory.bakery: Color(0xFFB07B2E),
  ProductCategory.meatAndFish: Color(0xFFC2544D),
  ProductCategory.dairyAndEggs: Color(0xFF3E7BB6),
  ProductCategory.frozen: Color(0xFF2E93A8),
  ProductCategory.pantry: Color(0xFF8A6534),
  ProductCategory.drinks: Color(0xFF7A5AA8),
  ProductCategory.household: Color(0xFF4F8A8B),
  ProductCategory.other: Color(0xFF6B7280),
};

/// The same nine hues lifted for a dark ground: the light values are
/// mid-tones that disappear against #121510.
const Map<ProductCategory, Color> _aislesDark = {
  ProductCategory.produce: Color(0xFF8FC169),
  ProductCategory.bakery: Color(0xFFD6A863),
  ProductCategory.meatAndFish: Color(0xFFE08C85),
  ProductCategory.dairyAndEggs: Color(0xFF7FAEDD),
  ProductCategory.frozen: Color(0xFF6AC0D0),
  ProductCategory.pantry: Color(0xFFC2A075),
  ProductCategory.drinks: Color(0xFFAE91D6),
  ProductCategory.household: Color(0xFF85BBBC),
  ProductCategory.other: Color(0xFF9AA1AC),
};

extension AppPaletteContext on BuildContext {
  /// The palette for the current theme. Falls back to [AppPalette.light]
  /// only if a widget is built outside the app's theme, as in a bare test.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
