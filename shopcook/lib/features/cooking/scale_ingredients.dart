/// The number of servings a recipe is written for, from however the site
/// words it ("6", "Makes 12", "4-6 порции"), or null when it gives none.
int? baseServings(String servings) {
  final match = RegExp(r'\d+').firstMatch(servings);
  final value = match == null ? null : int.tryParse(match.group(0)!);
  return value == null || value <= 0 ? null : value;
}

const _glyphs = {'½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3};

// One amount: "1 1/2", "1/2", "1½", "½", "1.5", "1,5", "600".
const _amount =
    r'(?:\d+\s+\d+/\d+|\d+/\d+|\d*[½¼¾⅓⅔]|\d+(?:[.,]\d+)?)';

// An amount at the start of a line, optionally a range ("4–5", "36-40"),
// optionally after "about" — "около 36-40 бр. бишкоти".
final _leading = RegExp(
  '^((?:около|about|approx\\.?|ca\\.?)\\s+)?($_amount)(\\s*[-–—]\\s*($_amount))?',
  caseSensitive: false,
);

/// [line] with the amount it starts with multiplied by [factor]. Lines with
/// no leading amount ("сол на вкус", "salt to taste") come back unchanged.
String scaleIngredientLine(String line, double factor) {
  if (factor == 1) return line;
  final match = _leading.firstMatch(line);
  if (match == null) return line;

  final low = _parse(match.group(2)!);
  if (low == null) return line;
  // Keep the line's own style: "1,5 кг" stays decimal, "1/2 tsp" goes to
  // fractions.
  final written = match.group(0)!;
  final comma = written.contains(',');
  final decimal = RegExp(r'\d[.,]\d').hasMatch(written);
  final prefix = match.group(1) ?? '';

  String format(double v) =>
      formatAmount(v, comma: comma, decimal: decimal);
  var scaled = format(low * factor);
  final high = match.group(4) == null ? null : _parse(match.group(4)!);
  if (high != null) scaled = '$scaled–${format(high * factor)}';
  return '$prefix$scaled${line.substring(match.end)}';
}

double? _parse(String text) {
  final t = text.trim();
  final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(t);
  if (mixed != null) {
    final den = int.parse(mixed.group(3)!);
    if (den == 0) return null;
    return int.parse(mixed.group(1)!) + int.parse(mixed.group(2)!) / den;
  }
  final fraction = RegExp(r'^(\d+)/(\d+)$').firstMatch(t);
  if (fraction != null) {
    final den = int.parse(fraction.group(2)!);
    return den == 0 ? null : int.parse(fraction.group(1)!) / den;
  }
  final glyph = RegExp(r'^(\d*)([½¼¾⅓⅔])$').firstMatch(t);
  if (glyph != null) {
    final whole = glyph.group(1)!.isEmpty ? 0 : int.parse(glyph.group(1)!);
    return whole + _glyphs[glyph.group(2)!]!;
  }
  return double.tryParse(t.replaceAll(',', '.'));
}

/// An amount as a cook would write it: whole numbers above ten, kitchen
/// fractions below ("1½", "¾"), one decimal only when neither fits. With
/// [decimal], fractions are skipped for "4,5" style.
String formatAmount(
  double value, {
  bool comma = false,
  bool decimal = false,
}) {
  if (value >= 10) return value.round().toString();
  if (decimal) {
    // Two places under one ("0,15 л"), where a single one would round a
    // real amount away; trailing zeros dropped either way.
    final text = value
        .toStringAsFixed(value < 1 ? 2 : 1)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return comma ? text.replaceAll('.', ',') : text;
  }

  final whole = value.floor();
  final rest = value - whole;
  final nearest = <double, String>{
    0.0: '',
    for (final glyph in _glyphs.entries) glyph.value: glyph.key,
    1.0: '',
  };
  for (final entry in nearest.entries) {
    if ((rest - entry.key).abs() < 0.04) {
      final w = entry.key == 1.0 ? whole + 1 : whole;
      if (entry.value.isEmpty) return '$w';
      return w == 0 ? entry.value : '$w${entry.value}';
    }
  }
  final text = value.toStringAsFixed(1);
  return comma ? text.replaceAll('.', ',') : text;
}
