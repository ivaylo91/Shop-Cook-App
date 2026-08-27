import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Aisles in the rough order you walk a supermarket.
enum ProductCategory {
  produce('Produce', FontAwesomeIcons.carrot),
  bakery('Bakery', FontAwesomeIcons.breadSlice),
  meatAndFish('Meat & fish', FontAwesomeIcons.drumstickBite),
  dairyAndEggs('Dairy & eggs', FontAwesomeIcons.egg),
  frozen('Frozen', FontAwesomeIcons.snowflake),
  pantry('Pantry', FontAwesomeIcons.jar),
  drinks('Drinks', FontAwesomeIcons.mugHot),
  household('Household', FontAwesomeIcons.soap),
  other('Other', FontAwesomeIcons.basketShopping);

  const ProductCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Keywords matched against the product name, lowercase.
const Map<ProductCategory, List<String>> _keywords = {
  ProductCategory.produce: [
    'apple', 'avocado', 'banana', 'basil', 'berry', 'broccoli', 'cabbage',
    'carrot', 'celery', 'cucumber', 'eggplant', 'garlic', 'grape', 'herb',
    'lemon', 'lettuce', 'lime', 'mushroom', 'onion', 'orange', 'parsley',
    'pepper', 'potato', 'salad', 'spinach', 'strawberr', 'tomato', 'zucchini',
  ],
  ProductCategory.bakery: [
    'bagel', 'baguette', 'bread', 'bun', 'cake', 'croissant', 'pita', 'roll',
    'tortilla',
  ],
  ProductCategory.meatAndFish: [
    'bacon', 'beef', 'chicken', 'fish', 'ham', 'lamb', 'meat', 'mince',
    'pork', 'prawn', 'salmon', 'sausage', 'shrimp', 'steak', 'tuna', 'turkey',
  ],
  ProductCategory.dairyAndEggs: [
    'butter', 'cheddar', 'cheese', 'cream', 'egg', 'feta', 'milk',
    'mozzarella', 'parmesan', 'yoghurt', 'yogurt',
  ],
  ProductCategory.frozen: ['frozen', 'ice cream'],
  ProductCategory.pantry: [
    'bean', 'black pepper', 'cereal', 'flour', 'honey', 'jam', 'lentil',
    'noodle', 'oat', 'oil', 'pasta', 'peanut butter', 'puree', 'purée',
    'rice', 'salt', 'sauce', 'spaghetti', 'spice', 'stock', 'sugar',
    'tomato paste', 'vinegar',
  ],
  ProductCategory.drinks: [
    'beer', 'coffee', 'cola', 'juice', 'soda', 'tea', 'water', 'wine',
  ],
  ProductCategory.household: [
    'detergent', 'dish', 'foil', 'soap', 'towel', 'wrap',
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
