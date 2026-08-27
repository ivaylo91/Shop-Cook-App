import 'package:flutter/material.dart';

import '../features/shopping/product_category.dart';

/// Design tokens for ShopCook.
///
/// Spacing sits on an 8-point grid, the type scale is deliberately limited to
/// four sizes and two weights, and colour follows a 60/30/10 split: a neutral
/// base, dark text, and green reserved for actions and progress.

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

abstract final class AppColors {
  /// 60% — the neutral ground everything sits on.
  static const surface = Color(0xFFF6F8F2);
  static const card = Color(0xFFFFFFFF);

  /// 30% — text, at three levels of emphasis rather than three colours.
  static const ink = Color(0xFF1A1C18);
  static Color inkMuted = ink.withValues(alpha: 0.62);
  static Color inkFaint = ink.withValues(alpha: 0.38);

  /// 10% — the accent, kept for actions, checks and progress.
  static const accent = Color(0xFF2E7D32);
}

/// Soft, tinted shadow. Never pure grey on a coloured ground.
List<BoxShadow> softShadow(Color tint, {double opacity = 0.10}) => [
  BoxShadow(
    color: tint.withValues(alpha: opacity),
    blurRadius: 20,
    offset: const Offset(0, 6),
  ),
];

/// One hue per aisle, so sections are recognisable at a glance while
/// scanning. Used only as a tinted chip and icon, never as a large fill —
/// nine saturated blocks would wreck the 60/30/10 balance.
Color categoryColor(ProductCategory category) => switch (category) {
  ProductCategory.produce => const Color(0xFF4C8B2B),
  ProductCategory.bakery => const Color(0xFFB07B2E),
  ProductCategory.meatAndFish => const Color(0xFFC2544D),
  ProductCategory.dairyAndEggs => const Color(0xFF3E7BB6),
  ProductCategory.frozen => const Color(0xFF2E93A8),
  ProductCategory.pantry => const Color(0xFF8A6534),
  ProductCategory.drinks => const Color(0xFF7A5AA8),
  ProductCategory.household => const Color(0xFF4F8A8B),
  ProductCategory.other => const Color(0xFF6B7280),
};
