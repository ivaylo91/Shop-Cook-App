import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/features/recipes/ingredient_parser.dart';

void main() {
  group('parseIngredient', () {
    void expectParsed(
      String raw, {
      required String name,
      String quantity = '',
      String unit = '',
    }) {
      final result = parseIngredient(raw);
      expect(result.name, name, reason: 'name of "$raw"');
      expect(result.quantity, quantity, reason: 'quantity of "$raw"');
      expect(result.unit, unit, reason: 'unit of "$raw"');
    }

    test('splits amount, unit and name', () {
      expectParsed('500 g ground beef',
          name: 'Ground beef', quantity: '500', unit: 'g');
      expectParsed('2 tbsp tomato paste',
          name: 'Tomato paste', quantity: '2', unit: 'tbsp');
    });

    test('handles a unit stuck to the number', () {
      expectParsed('400g spaghetti',
          name: 'Spaghetti', quantity: '400', unit: 'g');
    });

    test('normalises unit spellings', () {
      expectParsed('2 tablespoons olive oil',
          name: 'Olive oil', quantity: '2', unit: 'tbsp');
      expectParsed('3 teaspoons salt',
          name: 'Salt', quantity: '3', unit: 'tsp');
      expectParsed('250 grams flour',
          name: 'Flour', quantity: '250', unit: 'g');
    });

    test('keeps a bare count without inventing a unit', () {
      // "onion" must not be mistaken for a unit just because it follows a number.
      expectParsed('1 onion', name: 'Onion', quantity: '1');
      expectParsed('3 large eggs', name: 'Large eggs', quantity: '3');
    });

    test('understands fractions', () {
      expectParsed('1/2 tsp black pepper',
          name: 'Black pepper', quantity: '1/2', unit: 'tsp');
      expectParsed('1 1/2 cups milk',
          name: 'Milk', quantity: '1 1/2', unit: 'cup');
      expectParsed('½ lemon', name: 'Lemon', quantity: '½');
    });

    test('understands ranges', () {
      expectParsed('2-3 cloves garlic',
          name: 'Garlic', quantity: '2-3', unit: 'clove');
    });

    test('drops preparation notes and parentheticals', () {
      expectParsed('1 onion, finely chopped', name: 'Onion', quantity: '1');
      expectParsed('200 g cheese (grated)',
          name: 'Cheese', quantity: '200', unit: 'g');
    });

    test('drops preparation notes written without a comma', () {
      // Real lines from BBC Good Food, which omits the comma.
      expectParsed('4 rashers smoked streaky bacon finely chopped',
          name: 'Rashers smoked streaky bacon', quantity: '4');
      expectParsed('2 medium onions finely chopped',
          name: 'Medium onions', quantity: '2');
      expectParsed('2 carrots trimmed and finely chopped',
          name: 'Carrots', quantity: '2');
      expectParsed('2-3 sprigs rosemary leaves picked and finely chopped',
          name: 'Rosemary leaves', quantity: '2-3', unit: 'sprig');
    });

    test('keeps products whose name begins with a preparation word', () {
      // You buy "chopped tomatoes" — that word is part of the product.
      expectParsed('400 g chopped tomatoes',
          name: 'Chopped tomatoes', quantity: '400', unit: 'g');
      expectParsed('1 tin crushed tomatoes',
          name: 'Crushed tomatoes', quantity: '1', unit: 'tin');
      expectParsed('200 g sliced ham',
          name: 'Sliced ham', quantity: '200', unit: 'g');
    });

    test('folds pack multipliers into the amount', () {
      // "2 x 400g tins plum tomatoes" is two tins, not a product called "x".
      expectParsed('2 x 400g tins plum tomatoes',
          name: 'Plum tomatoes', quantity: '2 × 400g', unit: 'tin');
      // With no further unit word after the pack size, the size keeps its
      // own unit and the amount reads whole: "3 × 200 ml".
      expectParsed('3 x 200 ml cream', name: 'Cream', quantity: '3 × 200 ml');
    });

    test('keeps unparseable lines whole rather than losing them', () {
      expectParsed('Salt and pepper to taste',
          name: 'Salt and pepper to taste');
      expectParsed('A pinch of saffron', name: 'A pinch of saffron');
    });

    test('survives empty input', () {
      expectParsed('', name: '');
      expectParsed('   ', name: '');
    });

    test('keeps the original line for display', () {
      expect(parseIngredient('500 g ground beef').original, '500 g ground beef');
    });
  });
}
