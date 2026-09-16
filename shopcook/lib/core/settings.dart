import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
