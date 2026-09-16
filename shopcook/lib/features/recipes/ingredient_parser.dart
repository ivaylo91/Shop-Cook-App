/// Recipe sites publish ingredients as free text — "500 g ground beef",
/// "2 tbsp tomato paste", "1 onion, finely chopped". Shopping list rows want
/// those split into a name, a quantity and a unit.
class ParsedIngredient {
  final String name;
  final String quantity;
  final String unit;

  /// The untouched source line, kept so the UI can show what was parsed.
  final String original;

  const ParsedIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.original,
  });
}

/// A leading amount: "2", "1.5", "1/2", "1 1/2", "2-3", or "½".
final _quantityPattern = RegExp(
  r'^((?:\d+\s+)?\d+\s*/\s*\d+'
  r'|\d+(?:[.,]\d+)?(?:\s*[-–—]\s*\d+(?:[.,]\d+)?)?'
  r'|[½¼¾⅓⅔⅛])',
);

/// A pack multiplier following the amount: the "x 400g" of "2 x 400g tins".
final _multiplierPattern = RegExp(
  r'^[x×]\s*(\d+(?:[.,]\d+)?\s*[a-zA-ZЀ-ӿ]*)\s+',
  caseSensitive: false,
);

/// A word straight after the amount, which may be a unit.
///
/// Cyrillic as well as Latin: a Bulgarian list says "2 кг картофи", and an
/// ASCII-only class would read the whole thing as a name.
final _leadingWordPattern = RegExp(r'^([a-zA-ZЀ-ӿ]+)\.?(?=\s|$)');

/// Words that begin a preparation note rather than name the thing you buy.
///
/// Many sites write "4 rashers smoked streaky bacon finely chopped" with no
/// comma, so the note has to be recognised by its wording. Only cut at these
/// when they are not the first word, because plenty of products lead with
/// one — "chopped tomatoes" and "crushed garlic" are things you buy.
const Set<String> _prepWords = {
  'beaten', 'chopped', 'coarsely', 'cooked', 'crushed', 'cubed', 'cut',
  'deseeded', 'defrosted', 'diced', 'drained', 'finely', 'freshly', 'grated',
  'halved', 'melted', 'minced', 'peeled', 'picked', 'plus', 'quartered',
  'rinsed', 'roughly', 'shredded', 'sliced', 'softened', 'thawed', 'thinly',
  'torn', 'trimmed', 'washed', 'zested',
  // Bulgarian. Same rule applies: never cut at the first word, because
  // "нарязани домати" is a thing you buy.
  'нарязан', 'нарязани', 'нарязана', 'нарязано', 'настърган', 'настъргани',
  'обелен', 'обелени', 'обелена', 'сварен', 'сварени', 'варен', 'варени',
  'ситно', 'едро', 'изцеден', 'изцедени', 'разбит', 'разбити', 'смлян',
  'смляна', 'смлени', 'почистен', 'почистени', 'измит', 'измити',
  'предварително', 'приблизително', 'прясно', 'на', 'без', 'плюс',
};

/// Unit spellings mapped to the short form worth showing on a list row.
const Map<String, String> _units = {
  'g': 'g', 'gr': 'g', 'gram': 'g', 'grams': 'g', 'gramme': 'g',
  'grammes': 'g',
  'kg': 'kg', 'kilo': 'kg', 'kilos': 'kg', 'kilogram': 'kg',
  'kilograms': 'kg',
  'mg': 'mg',
  'ml': 'ml', 'millilitre': 'ml', 'millilitres': 'ml', 'milliliter': 'ml',
  'milliliters': 'ml',
  'l': 'l', 'litre': 'l', 'litres': 'l', 'liter': 'l', 'liters': 'l',
  'tbsp': 'tbsp', 'tablespoon': 'tbsp', 'tablespoons': 'tbsp',
  'tsp': 'tsp', 'teaspoon': 'tsp', 'teaspoons': 'tsp',
  'cup': 'cup', 'cups': 'cup',
  'oz': 'oz', 'ounce': 'oz', 'ounces': 'oz',
  'lb': 'lb', 'lbs': 'lb', 'pound': 'lb', 'pounds': 'lb',
  'clove': 'clove', 'cloves': 'clove',
  'can': 'can', 'cans': 'can', 'tin': 'tin', 'tins': 'tin',
  'jar': 'jar', 'jars': 'jar',
  'pinch': 'pinch', 'pinches': 'pinch',
  'slice': 'slice', 'slices': 'slice',
  'bunch': 'bunch', 'bunches': 'bunch',
  'handful': 'handful', 'handfuls': 'handful',
  'sprig': 'sprig', 'sprigs': 'sprig',
  'stick': 'stick', 'sticks': 'stick',
  'packet': 'packet', 'packets': 'packet', 'pack': 'pack',

  // Bulgarian. Dotted abbreviations ("с.л.", "ч.л.") are folded to a
  // dotless key before lookup — see _collapseDottedUnits — because the
  // leading-word pattern stops at the first dot.
  'г': 'г', 'гр': 'г', 'грам': 'г', 'грама': 'г', 'грамa': 'г',
  'кг': 'кг', 'килограм': 'кг', 'килограма': 'кг',
  'мг': 'мг',
  'мл': 'мл', 'милилитър': 'мл', 'милилитра': 'мл',
  'л': 'л', 'литър': 'л', 'литра': 'л',
  'сл': 'с.л.', 'чл': 'ч.л.',
  'бр': 'бр.', 'брой': 'бр.', 'броя': 'бр.',
  'щипка': 'щипка', 'щипки': 'щипка',
  'скилидка': 'скилидка', 'скилидки': 'скилидка',
  'консерва': 'консерва', 'консерви': 'консерва',
  'кутия': 'кутия', 'кутии': 'кутия',
  'буркан': 'буркан', 'буркана': 'буркан',
  'пакет': 'пакет', 'пакета': 'пакет', 'пакетче': 'пакетче',
  'чаша': 'чаша', 'чаши': 'чаша',
  'връзка': 'връзка', 'връзки': 'връзка',
  'стрък': 'стрък', 'стръка': 'стрък',
  'резен': 'резен', 'резена': 'резен', 'филия': 'филия', 'филии': 'филия',
  'шепа': 'шепа',
  // "1 глава лук" is a head of onion, the same shape as "1 clove".
  'глава': 'глава', 'глави': 'глава',
};

/// Folds "с. л." and "ч.л." to "сл" / "чл" so the unit lookup sees one word.
///
/// Bulgarian recipes abbreviate spoon measures with dots, and the
/// leading-word pattern stops at the first one.
final _dottedUnitPattern = RegExp(
  r'^([счСЧ])\s*\.?\s*(л|Л)\s*\.?(?=\s|$)',
);

String _collapseDottedUnits(String text) {
  return text.replaceFirstMapped(
    _dottedUnitPattern,
    (m) => '${m.group(1)!.toLowerCase()}${m.group(2)!.toLowerCase()}',
  );
}

/// Splits one recipe ingredient line into shopping-list fields.
///
/// Anything it cannot confidently split is kept whole as the name, which is
/// always better than dropping detail the shopper needs.
ParsedIngredient parseIngredient(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) {
    return ParsedIngredient(name: '', quantity: '', unit: '', original: raw);
  }

  var rest = text;
  var quantity = '';
  var unit = '';

  final amount = _quantityPattern.firstMatch(rest);
  if (amount != null) {
    quantity = amount.group(0)!.replaceAll(' ', ' ').trim();
    rest = rest.substring(amount.end).trim();

    // Pack multipliers: "2 x 400g tins plum tomatoes". Fold the pack size
    // into the amount so the unit and name after it still parse.
    final multiplier = _multiplierPattern.firstMatch(rest);
    if (multiplier != null) {
      quantity = '$quantity × ${multiplier.group(1)!.trim()}';
      rest = rest.substring(multiplier.end).trim();
    }

    // Only treat the next word as a unit when an amount preceded it,
    // so "1 onion" keeps "onion" as the name rather than a unit.
    rest = _collapseDottedUnits(rest);
    final word = _leadingWordPattern.firstMatch(rest);
    if (word != null) {
      final canonical = _units[word.group(1)!.toLowerCase()];
      if (canonical != null) {
        unit = canonical;
        rest = rest.substring(word.end).trim();
      }
    }
  }

  var name = rest;

  // "1 onion, finely chopped" — the preparation note is not shopping info.
  final comma = name.indexOf(',');
  if (comma > 0) name = name.substring(0, comma);

  name = name
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // "bacon finely chopped" → "bacon". Never cut at the first word, so
  // "chopped tomatoes" survives intact.
  final words = name.split(' ');
  for (var i = 1; i < words.length; i++) {
    if (_prepWords.contains(words[i].toLowerCase())) {
      name = words.take(i).join(' ');
      break;
    }
  }
  name = name.replaceFirst(RegExp(r'[\s,]+(and|or|with)$', caseSensitive: false), '').trim();

  // Nothing recognisable left: keep the whole line rather than lose it.
  if (name.isEmpty) {
    return ParsedIngredient(
      name: text,
      quantity: '',
      unit: '',
      original: raw,
    );
  }

  return ParsedIngredient(
    name: name[0].toUpperCase() + name.substring(1),
    quantity: quantity,
    unit: unit,
    original: raw,
  );
}
