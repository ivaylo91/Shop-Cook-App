import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Set once here so every Text inherits it; the tokens in design.dart
    // deliberately leave fontFamily unset and merge over this.
    fontFamily: 'Figtree',
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
  );
}
