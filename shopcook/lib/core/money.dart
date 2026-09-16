import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formatting and parsing for item prices.
///
/// The currency comes from the reader's locale rather than a setting: a
/// Bulgarian phone gets лв., an English one gets its own. That is a guess, but
/// it is the right guess far more often than a hardcoded symbol, and asking
/// someone to pick a currency before they can note down what milk cost would
/// be worse than being occasionally wrong.
extension MoneyContext on BuildContext {
  /// e.g. "2,40 лв." in bg, "$2.40" in en.
  String money(double amount) => NumberFormat.simpleCurrency(
    locale: Localizations.localeOf(this).toLanguageTag(),
  ).format(amount);
}

/// Reads a typed price, tolerating either decimal separator.
///
/// Bulgarian writes 2,40 and English 2.40, and a keyboard offers whichever it
/// feels like — rejecting the "wrong" one would just look broken.
double? parsePrice(String raw) {
  final text = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (text.isEmpty) return null;

  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) return null;
  // A negative price is a typo, not a refund.
  if (value < 0) return null;

  return value;
}
