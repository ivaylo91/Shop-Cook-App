import 'package:flutter/material.dart';

import 'design.dart';

/// Builds the app theme for one brightness from [AppPalette].
///
/// The scheme starts from a seed so every Material slot is filled with
/// something harmonious, then the slots the UI actually shows are pinned to
/// the palette. Seeding alone was the old bug: `fromSeed` generates its own
/// ramp of greens and greys, so a screen reading `Theme.of(context)` and a
/// screen reading the tokens rendered two different apps. Pinning the visible
/// slots means plain Material widgets are on the design system for free —
/// which is what makes the untouched screens presentable before anyone
/// rewrites their layout.
ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        surface: palette.surface,
        onSurface: palette.ink,
        onSurfaceVariant: palette.inkMuted,
        surfaceContainerLowest: palette.card,
        surfaceContainerLow: palette.card,
        surfaceContainer: palette.sunken,
        surfaceContainerHigh: palette.sunken,
        outlineVariant: palette.divider,
      );

  // AppText leaves colour and family unset so it can be merged over. Mapped
  // onto the slots Material widgets read: ListTile takes its title from
  // bodyLarge and its subtitle from bodyMedium, dialogs take their title
  // from headlineSmall.
  final textTheme = TextTheme(
    displaySmall: AppText.display.copyWith(color: palette.ink),
    headlineMedium: AppText.display.copyWith(fontSize: 26, color: palette.ink),
    headlineSmall: AppText.title.copyWith(fontSize: 21, color: palette.ink),
    titleLarge: AppText.title.copyWith(fontSize: 19, color: palette.ink),
    titleMedium: AppText.title.copyWith(color: palette.ink),
    titleSmall: AppText.body.copyWith(
      fontWeight: FontWeight.w600,
      color: palette.ink,
    ),
    bodyLarge: AppText.title.copyWith(color: palette.ink),
    bodyMedium: AppText.body.copyWith(color: palette.ink),
    bodySmall: AppText.caption.copyWith(color: palette.inkMuted),
    labelLarge: AppText.body.copyWith(fontWeight: FontWeight.w600),
    labelMedium: AppText.caption.copyWith(fontWeight: FontWeight.w600),
    labelSmall: AppText.caption.copyWith(color: palette.inkFaint),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: palette.surface,
    // Set once here so every Text inherits it; the tokens in design.dart
    // deliberately leave fontFamily unset and merge over this.
    fontFamily: 'Figtree',
  );

  // Component themes are derived with copyWith rather than by naming each
  // theme-data class, so this file does not have to track Flutter's renaming
  // of the older ones (CardTheme, DialogTheme and friends).
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[palette],

    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: palette.surface,
      foregroundColor: palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.title.copyWith(
        fontFamily: 'Figtree',
        color: palette.ink,
      ),
      iconTheme: IconThemeData(color: palette.ink, size: 20),
      actionsIconTheme: IconThemeData(color: palette.ink, size: 20),
    ),

    cardTheme: base.cardTheme.copyWith(
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
    ),

    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      titleTextStyle: AppText.title.copyWith(
        fontFamily: 'Figtree',
        fontSize: 19,
        color: palette.ink,
      ),
      contentTextStyle: AppText.body.copyWith(
        fontFamily: 'Figtree',
        color: palette.inkMuted,
      ),
    ),

    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: palette.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: palette.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: palette.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      labelStyle: AppText.body.copyWith(color: palette.inkMuted),
      hintStyle: AppText.body.copyWith(color: palette.inkFaint),
      prefixIconColor: palette.inkMuted,
      suffixIconColor: palette.inkMuted,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: palette.inkMuted,
      textColor: palette.ink,
      titleTextStyle: AppText.title.copyWith(
        fontFamily: 'Figtree',
        color: palette.ink,
      ),
      subtitleTextStyle: AppText.caption.copyWith(
        fontFamily: 'Figtree',
        color: palette.inkMuted,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(palette.onAccent),
      side: BorderSide(color: palette.ink.withValues(alpha: 0.28), width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      visualDensity: VisualDensity.compact,
    ),

    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 1,
    ),

    iconTheme: IconThemeData(color: palette.inkMuted, size: 20),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        textStyle: AppText.body.copyWith(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        minimumSize: const Size(0, 44),
        textStyle: AppText.body.copyWith(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: palette.divider),
        textStyle: AppText.body.copyWith(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.inkMuted,
        // 48dp keeps every icon button hittable one-handed, which the 14px
        // icons dotted around the app were not.
        minimumSize: const Size(48, 48),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accent,
      foregroundColor: palette.onAccent,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 1,
      extendedTextStyle: AppText.body.copyWith(
        fontFamily: 'Figtree',
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.isDark ? palette.sunken : palette.ink,
      contentTextStyle: AppText.body.copyWith(
        fontFamily: 'Figtree',
        color: palette.isDark ? palette.ink : palette.card,
      ),
      actionTextColor: palette.accent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(Insets.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      dragHandleColor: palette.inkFaint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      textStyle: AppText.body.copyWith(
        fontFamily: 'Figtree',
        color: palette.ink,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.sunken,
      circularTrackColor: Colors.transparent,
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.accent,
      selectionColor: palette.accent.withValues(alpha: 0.24),
      selectionHandleColor: palette.accent,
    ),

    splashColor: palette.accent.withValues(alpha: 0.08),
    highlightColor: palette.accent.withValues(alpha: 0.05),
  );
}
