import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/shopping/product_category.dart';

/// Overridden in `main()` with an instance loaded before the first frame, so
/// the app opens in the theme the user chose instead of rendering the default
/// and then snapping to it.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

const _themeModeKey = 'themeMode';

/// The chosen theme mode, read synchronously at startup and written back on
/// every change.
///
/// [ThemeMode.system] is the default rather than light: following the phone
/// is what a user who has set their phone to dark expects.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(_themeModeKey);

    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_themeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

const _localeKey = 'locale';

/// The chosen language, or null to follow the phone.
///
/// Null is the default and is not the same as English: a Bulgarian phone
/// should open the app in Bulgarian without anyone choosing anything. The
/// override exists for the case where the phone's language is not the one you
/// want to cook in.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_localeKey);
    if (stored == null || stored.isEmpty) return null;
    return Locale(stored);
  }

  Future<void> set(Locale? locale) async {
    if (locale == state) return;
    state = locale;

    final preferences = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await preferences.remove(_localeKey);
    } else {
      await preferences.setString(_localeKey, locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

const _aisleOrderKey = 'aisleOrder';

/// The order aisles appear in while shopping.
///
/// Stored as enum names, not indices: a release that adds or reorders
/// [ProductCategory] would otherwise silently shuffle everyone's saved order.
/// Unknown names are dropped and missing ones appended, so a saved order
/// written by an older or newer build still resolves to something sensible
/// rather than losing aisles.
class AisleOrderController extends Notifier<List<ProductCategory>> {
  @override
  List<ProductCategory> build() {
    final stored = ref.watch(sharedPreferencesProvider)
        .getStringList(_aisleOrderKey);
    return _resolve(stored);
  }

  static List<ProductCategory> _resolve(List<String>? names) {
    if (names == null || names.isEmpty) return ProductCategory.values;

    final byName = {for (final c in ProductCategory.values) c.name: c};
    final ordered = [
      for (final name in names)
        if (byName[name] != null) byName[name]!,
    ];
    // Anything the saved order does not mention still has to appear.
    for (final category in ProductCategory.values) {
      if (!ordered.contains(category)) ordered.add(category);
    }
    return ordered;
  }

  Future<void> set(List<ProductCategory> order) async {
    state = _resolve([for (final c in order) c.name]);
    await ref.read(sharedPreferencesProvider).setStringList(
      _aisleOrderKey,
      [for (final c in state) c.name],
    );
  }

  Future<void> reset() async {
    state = ProductCategory.values;
    await ref.read(sharedPreferencesProvider).remove(_aisleOrderKey);
  }

  /// Moves one aisle.
  ///
  /// Takes `onReorderItem` semantics: [newIndex] is already the destination
  /// after the item has been lifted out, so there is no off-by-one to correct
  /// here. The deprecated `onReorder` needed that correction; doing it in both
  /// places would move the item one slot too far.
  Future<void> reorder(int oldIndex, int newIndex) {
    final next = [...state];
    next.insert(newIndex, next.removeAt(oldIndex));
    return set(next);
  }
}

final aisleOrderProvider =
    NotifierProvider<AisleOrderController, List<ProductCategory>>(
      AisleOrderController.new,
    );
