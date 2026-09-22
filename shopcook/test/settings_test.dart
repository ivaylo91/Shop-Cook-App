import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopcook/core/settings.dart';

/// A container with real (mocked) preferences behind the provider.
Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('language', () {
    test('English until someone chooses otherwise', () async {
      final container = await containerWith({});
      expect(container.read(localeProvider), const Locale('en'));
      expect(defaultLocale, const Locale('en'));
    });

    test('a chosen language is remembered', () async {
      final container = await containerWith({});
      await container
          .read(localeProvider.notifier)
          .set(const Locale('bg'));
      expect(container.read(localeProvider), const Locale('bg'));

      final reopened = await containerWith({'locale': 'bg'});
      expect(reopened.read(localeProvider), const Locale('bg'));
    });

    test('"follow the phone" is a choice, not the absence of one', () async {
      final container = await containerWith({'locale': 'bg'});
      await container.read(localeProvider.notifier).set(null);
      expect(container.read(localeProvider), isNull);

      // Reopening keeps following the phone rather than falling back to
      // English, which would ignore what the reader picked.
      final reopened = await containerWith({'locale': 'system'});
      expect(reopened.read(localeProvider), isNull);
    });
  });

  test('theme follows the phone until chosen', () async {
    final container = await containerWith({});
    expect(container.read(themeModeProvider), ThemeMode.system);

    await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
