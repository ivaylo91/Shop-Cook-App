import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Aisles in the rough order you walk a supermarket.
///
/// The name is not stored here: an aisle heading is UI text and has to be
/// translated, so it is looked up per locale. See `localizedLabel`.
enum ProductCategory {
  produce(FontAwesomeIcons.carrot),
  bakery(FontAwesomeIcons.breadSlice),
  meatAndFish(FontAwesomeIcons.drumstickBite),
  dairyAndEggs(FontAwesomeIcons.egg),
  frozen(FontAwesomeIcons.snowflake),
  pantry(FontAwesomeIcons.jar),
  drinks(FontAwesomeIcons.mugHot),
  household(FontAwesomeIcons.soap),
  other(FontAwesomeIcons.basketShopping);

  const ProductCategory(this.icon);

  final FaIconData icon;
}

/// Keywords matched against the product name, lowercase.
///
/// Both languages live in one map on purpose. A shopping list is not
/// monolingual — the same person writes "мляко" one week and "halloumi" the
/// next — so matching is by word, not by the app's current locale. Bulgarian
/// entries are stems rather than whole words ("домат" covers домат, домати,
/// доматен) because the language inflects and `contains` is what does the
/// matching.
const Map<ProductCategory, List<String>> _keywords = {
  ProductCategory.produce: [
    'apple', 'avocado', 'banana', 'basil', 'berry', 'broccoli', 'cabbage',
    'carrot', 'celery', 'cucumber', 'eggplant', 'garlic', 'grape', 'herb',
    'lemon', 'lettuce', 'lime', 'mushroom', 'onion', 'orange', 'parsley',
    'pepper', 'potato', 'salad', 'spinach', 'strawberr', 'tomato', 'zucchini',
    'ябълк', 'авокадо', 'банан', 'босилек', 'броколи', 'зеле', 'морков',
    'целина', 'краставиц', 'патладжан', 'чесън', 'грозде', 'лимон',
    'маруля', 'салат', 'гъб', 'лук', 'портокал', 'магданоз', 'пипер',
    'картоф', 'спанак', 'ягод', 'домат', 'тиквичк', 'круш', 'слив',
    'прасков', 'диня', 'пъпеш', 'копър', 'репичк', 'цвекло', 'тиква',
    'малин', 'череш', 'кайси', 'киви', 'манго', 'джинджифил', 'маслин',
  ],
  ProductCategory.bakery: [
    'bagel', 'baguette', 'bread', 'bun', 'cake', 'croissant', 'pita', 'roll',
    'tortilla',
    'хляб', 'хлебч', 'питк', 'кифл', 'козунак', 'франзел', 'багет',
    'кроасан', 'симид', 'тортил', 'пита', 'сухар', 'бисквит', 'торта',
    'баница', 'точени кори', 'кори за баница',
  ],
  ProductCategory.meatAndFish: [
    'bacon', 'beef', 'chicken', 'fish', 'ham', 'lamb', 'meat', 'mince',
    'pork', 'prawn', 'salmon', 'sausage', 'shrimp', 'steak', 'tuna', 'turkey',
    'бекон', 'телешк', 'пилешк', 'пиле', 'риба', 'шунка', 'агнешк', 'месо',
    'кайма', 'свинск', 'скарид', 'сьомга', 'надениц', 'колбас', 'кренвирш',
    'луканк', 'салам', 'пастърма', 'стек', 'пъстърв', 'скумрия', 'тон',
    'миди', 'кюфте', 'дроб', 'патешк', 'заешк',
  ],
  ProductCategory.dairyAndEggs: [
    'butter', 'cheddar', 'cheese', 'cream', 'egg', 'feta', 'milk',
    'mozzarella', 'parmesan', 'yoghurt', 'yogurt',
    'масло', 'кашкавал', 'сирене', 'сметана', 'яйц', 'мляко', 'млечн',
    'моцарела', 'парменджано', 'извара', 'кисело мляко', 'айран',
    'крема сирене', 'топено сирене', 'фета', 'маскарпоне', 'рикота',
  ],
  ProductCategory.frozen: [
    'frozen', 'ice cream',
    'замразен', 'сладолед', 'фризер',
  ],
  ProductCategory.pantry: [
    'bean', 'black pepper', 'cereal', 'flour', 'honey', 'jam', 'lentil',
    'noodle', 'oat', 'oil', 'pasta', 'peanut butter', 'puree', 'purée',
    'rice', 'salt', 'sauce', 'spaghetti', 'spice', 'stock', 'sugar',
    'tomato paste', 'vinegar',
    'боб', 'черен пипер', 'зърнена закуска', 'мюсли', 'брашно', 'мед',
    'конфитюр', 'мармалад', 'леща', 'нахут', 'юфка', 'овес', 'олио',
    'зехтин', 'паста', 'макарон', 'спагет', 'фъстъчено масло', 'пюре',
    'ориз', 'сол', 'сос', 'подправк', 'бульон', 'захар', 'домат паста',
    'доматено пюре', 'оцет', 'булгур', 'кускус', 'грис', 'нишесте', 'сода',
    'бакпулвер', 'ванилия', 'какао', 'канела', 'чубрица', 'риган', 'кимион',
    'дафинов', 'мая', 'тахан', 'орех', 'бадем', 'семки', 'стафид',
    'кокосово мляко', 'консерв',
  ],
  ProductCategory.drinks: [
    'beer', 'coffee', 'cola', 'juice', 'soda', 'tea', 'water', 'wine',
    'бира', 'кафе', 'кола', 'сок', 'газиран', 'чай', 'вода', 'вино',
    'лимонада', 'ракия', 'уиски', 'айрян', 'боза', 'енергийна напитка',
  ],
  ProductCategory.household: [
    'detergent', 'dish', 'foil', 'soap', 'towel', 'wrap',
    'препарат', 'прах за пране', 'омекотител', 'сапун', 'шампоан', 'фолио',
    'салфетк', 'тоалетна хартия', 'домакинска хартия', 'гъба за съдове',
    'торб', 'белина', 'паста за зъби', 'домакинск',
  ],
};

/// Best-guess aisle for [productName].
ProductCategory categorize(String productName) {
  final name = productName.toLowerCase().trim();
  if (name.isEmpty) return ProductCategory.other;

  // Multi-word keywords are deliberate disambiguations, so they beat any
  // single word they contain: "tomato paste" is pantry, not produce, and
  // "ice cream" is frozen, not dairy.
  final phrase = _bestMatch(
    (keyword) => keyword.contains(' ') && name.contains(keyword),
  );
  if (phrase != null) return phrase;

  // Otherwise the last word is the head noun — "orange juice" is a juice
  // rather than an orange. `contains` rather than `==` so plurals still
  // match ("bananas" → "banana").
  final head = name.split(RegExp(r'\s+')).last;
  final headMatch = _bestMatch((keyword) => head.contains(keyword));
  if (headMatch != null) return headMatch;

  // Last resort: anything mentioned anywhere in the name.
  return _bestMatch((keyword) => name.contains(keyword)) ??
      ProductCategory.other;
}

/// The category whose longest keyword satisfies [matches], if any.
ProductCategory? _bestMatch(bool Function(String keyword) matches) {
  ProductCategory? best;
  var bestLength = 0;

  for (final entry in _keywords.entries) {
    for (final keyword in entry.value) {
      if (keyword.length > bestLength && matches(keyword)) {
        best = entry.key;
        bestLength = keyword.length;
      }
    }
  }
  return best;
}
