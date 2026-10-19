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
  static const card = 22.0;

  /// The one banner at the top of a screen, a touch rounder than a card.
  static const hero = 24.0;
  static const pill = 999.0;
}

/// One vocabulary for movement, so a check-off on one screen feels like a
/// check-off on another.
///
/// [fast] is for state that should feel instant (a tick, a tint change),
/// [base] for anything that moves or resizes, and [slow] for a deliberate
/// moment the user is meant to notice.
abstract final class Motion {
  /// Press feedback, and anything seen tens of times a day.
  static const fast = Duration(milliseconds: 140);

  /// The default for interface motion. Nothing routine runs longer.
  static const base = Duration(milliseconds: 220);

  /// A bottom sheet coming up. Longer than [base] because it travels
  /// further, and its curve spends most of that settling.
  static const sheet = Duration(milliseconds: 300);

  /// Only for the rare moment: a celebration, a chart drawing itself.
  static const slow = Duration(milliseconds: 440);

  /// A strong ease-out — cubic-bezier(0.23, 1, 0.32, 1) — for everything
  /// that enters, leaves or answers a touch. It moves most in its first
  /// frames, which is when the user is watching. There is deliberately no
  /// ease-in: starting slowly delays exactly that moment.
  static const enter = Curves.easeOutQuint;

  /// The iOS-style drawer curve — cubic-bezier(0.32, 0.72, 0, 1) — for
  /// sheets: off quickly, then a long settle, as if pulled up by hand.
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  /// Slight overshoot, for the one thing per screen worth celebrating.
  static const emphasis = Curves.easeOutBack;

  /// How far apart neighbours start when several things enter together.
  static const stagger = Duration(milliseconds: 40);
}

extension MotionContext on BuildContext {
  /// Whether the phone is set to remove animations. Movement and scaling
  /// are dropped then; fades stay, since they explain a change without
  /// moving anything.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
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
    surface: Color(0xFFF1F7F2),
    card: Color(0xFFFFFFFF),
    sunken: Color(0xFFE5F1E9),
    ink: Color(0xFF13261D),
    inkMuted: Color(0xFF56665D),
    inkFaint: Color(0xFF6A776F),
    // Emerald, deep enough for white text on it: 5.0:1.
    accent: Color(0xFF17805B),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFFE0ECE4),
  );

  /// Not an inversion of [light]: the ground is lifted off pure black so
  /// cards can sit above it, and the accent is lightened because #2E7D32 on
  /// a dark ground is too low-contrast to carry a label.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    surface: Color(0xFF0F1612),
    card: Color(0xFF18211C),
    sunken: Color(0xFF1F2A23),
    ink: Color(0xFFE6EFE9),
    inkMuted: Color(0xFFA9B8AF),
    inkFaint: Color(0xFF8E9D94),
    accent: Color(0xFF5CC995),
    onAccent: Color(0xFF06241A),
    divider: Color(0xFF2A362F),
  );

  bool get isDark => brightness == Brightness.dark;

  /// The screen ground: mint at the top through cream to a peach glow at
  /// the bottom, as on a fresh-produce stall. Runs almost straight down
  /// (172° in CSS terms). Behind every page (see Backdrop); cards sit on
  /// it as frosted glass.
  LinearGradient get ground => LinearGradient(
    begin: const Alignment(-0.14, -1),
    end: const Alignment(0.14, 1),
    colors: isDark
        ? const [
            Color(0xFF10201A),
            Color(0xFF0F1612),
            Color(0xFF14130F),
            Color(0xFF1C1713),
          ]
        : const [
            Color(0xFFD9F0E5),
            Color(0xFFEEF6F0),
            Color(0xFFF8F3EC),
            Color(0xFFFCE9DD),
          ],
    stops: const [0, 0.38, 0.70, 1],
  );

  /// Deep green for text set on a pale green or peach banner.
  Color get heroInk => isDark ? ink : const Color(0xFF0E5A3F);

  /// A pale tile behind an aisle's picture: each aisle its own pastel, as
  /// on the shelf signs of a market. In dark mode, the aisle's hue washed
  /// into the card colour instead.
  Color aisleTile(ProductCategory category) => isDark
      ? Color.alphaBlend(aisle(category).withValues(alpha: 0.18), card)
      : _aisleTilesLight[category]!;

  /// A round control floating on the ground: white, nearly opaque.
  Color get floating => isDark
      ? card.withValues(alpha: 0.92)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.88);

  /// A card's fill: white, slightly see-through, so the ground's colour
  /// warms it from behind without reaching the text.
  Color get glass => isDark
      ? card.withValues(alpha: 0.88)
      : card.withValues(alpha: 0.82);

  /// The bright rim along a glass card's edge.
  Color get glassEdge => isDark
      ? const Color(0x14FFFFFF)
      : const Color(0xE6FFFFFF);

  /// One hue per aisle, so sections are recognisable at a glance while
  /// scanning. Used only as a tinted chip and icon, never as a large fill —
  /// nine saturated blocks would wreck the 60/30/10 balance.
  Color aisle(ProductCategory category) =>
      (isDark ? _aislesDark : _aislesLight)[category]!;

  /// A tint laid over the plain surface, as a solid colour.
  ///
  /// For a tinted fill that sits on a screen's backdrop: a see-through tint
  /// would let the backdrop's pattern show under whatever is written on it.
  Color wash(Color tint, double alpha) =>
      Color.alphaBlend(tint.withValues(alpha: alpha), surface);

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

const Map<ProductCategory, Color> _aisleTilesLight = {
  ProductCategory.produce: Color(0xFFFDE4DC),
  ProductCategory.bakery: Color(0xFFF6E7D3),
  ProductCategory.meatAndFish: Color(0xFFFBE1E1),
  ProductCategory.dairyAndEggs: Color(0xFFE2EEFB),
  ProductCategory.frozen: Color(0xFFDDF0F5),
  ProductCategory.pantry: Color(0xFFFFEBD6),
  ProductCategory.drinks: Color(0xFFFFF2CF),
  ProductCategory.household: Color(0xFFDFF2E5),
  ProductCategory.other: Color(0xFFECEFEA),
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
