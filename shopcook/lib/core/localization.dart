import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Shorthand for the generated strings: `context.l10n.navLists`.
///
/// Non-nullable because `nullable-getter: false` in l10n.yaml — the delegate
/// is always installed by the root [WidgetsApp], so a null here would mean a
/// widget built outside the app, which is a bug rather than a case to handle.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The locales the app ships strings for, in the order they are offered.
const supportedAppLocales = [Locale('en'), Locale('bg')];

/// What to call a locale in the language picker.
///
/// Endonyms — each language named in itself — because someone who has the app
/// in a language they cannot read needs to recognise their own entry to get
/// out of it.
String localeEndonym(Locale locale) => switch (locale.languageCode) {
  'bg' => 'Български',
  'en' => 'English',
  _ => locale.languageCode,
};
