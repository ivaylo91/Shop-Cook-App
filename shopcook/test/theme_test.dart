import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/core/design.dart';
import 'package:shopcook/core/theme.dart';
import 'package:shopcook/features/shopping/product_category.dart';

void main() {
  group('buildAppTheme', () {
    for (final brightness in Brightness.values) {
      test('carries the matching palette for $brightness', () {
        final theme = buildAppTheme(brightness);
        final palette = theme.extension<AppPalette>();

        expect(palette, isNotNull);
        expect(palette!.brightness, brightness);
      });

      test('pins the visible scheme slots to the palette for $brightness', () {
        // The whole point of the theme pass: a widget reading
        // Theme.of(context) and a widget reading the tokens have to land on
        // the same colours, which seeding alone did not guarantee.
        final theme = buildAppTheme(brightness);
        final palette = theme.extension<AppPalette>()!;

        expect(theme.scaffoldBackgroundColor, palette.surface);
        expect(theme.colorScheme.surface, palette.surface);
        expect(theme.colorScheme.onSurface, palette.ink);
        expect(theme.colorScheme.primary, palette.accent);
        expect(theme.colorScheme.onPrimary, palette.onAccent);
        expect(theme.colorScheme.brightness, brightness);
      });

      test('sets the bundled family on body text for $brightness', () {
        final theme = buildAppTheme(brightness);
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Figtree');
      });
    }
  });

  group('AppPalette', () {
    test('resolves a colour for every aisle in both modes', () {
      // aisle() looks the category up with `!`, so a hue missing from either
      // map would throw at paint time rather than fail here.
      for (final palette in [AppPalette.light, AppPalette.dark]) {
        for (final category in ProductCategory.values) {
          expect(
            () => palette.aisle(category),
            returnsNormally,
            reason: '${category.name} has no hue for ${palette.brightness}',
          );
        }
      }
    });

    test('lerp snaps brightness rather than blending it', () {
      final quarter = AppPalette.light.lerp(AppPalette.dark, 0.25);
      final threeQuarters = AppPalette.light.lerp(AppPalette.dark, 0.75);

      expect(quarter.brightness, Brightness.light);
      expect(threeQuarters.brightness, Brightness.dark);
    });

    test('tints the shadow in light mode and blackens it in dark', () {
      const tint = Color(0xFFFF0000);

      expect(
        AppPalette.light.shadow(tint).first.color,
        tint.withValues(alpha: 0.10),
      );
      expect(
        AppPalette.dark.shadow(tint).first.color,
        const Color(0xFF000000).withValues(alpha: 0.10 * 3.4),
      );
    });
  });

  testWidgets('context.palette reads the palette off the theme', (
    tester,
  ) async {
    late AppPalette seen;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: Builder(
          builder: (context) {
            seen = context.palette;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(seen.brightness, Brightness.dark);
    expect(seen.accent, AppPalette.dark.accent);
  });
}
