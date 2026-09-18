import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/features/cooking/scale_ingredients.dart';

void main() {
  group('baseServings', () {
    test('reads the first number however it is worded', () {
      expect(baseServings('6'), 6);
      expect(baseServings('Makes 12'), 12);
      expect(baseServings('4-6 порции'), 4);
    });

    test('none given', () {
      expect(baseServings(''), isNull);
      expect(baseServings('a family'), isNull);
      expect(baseServings('0'), isNull);
    });
  });

  group('scaleIngredientLine', () {
    test('whole amounts, Bulgarian and English', () {
      expect(scaleIngredientLine('600 г телешка кайма', 0.5), '300 г телешка кайма');
      expect(scaleIngredientLine('100g plain flour', 2), '200g plain flour');
      expect(scaleIngredientLine('2 large eggs', 1.5), '3 large eggs');
    });

    test('small amounts become kitchen fractions', () {
      expect(scaleIngredientLine('1 ч. л. кимион', 0.5), '½ ч. л. кимион');
      expect(scaleIngredientLine('1 tbsp oil', 1.5), '1½ tbsp oil');
      expect(scaleIngredientLine('3 яйца', 0.25), '¾ яйца');
    });

    test('fractions in, fractions out', () {
      expect(scaleIngredientLine('1/2 tsp baking soda', 2), '1 tsp baking soda');
      expect(scaleIngredientLine('1 1/2 cups milk', 2), '3 cups milk');
      expect(scaleIngredientLine('½ глава лук', 3), '1½ глава лук');
      expect(scaleIngredientLine('1½ cups rice', 2), '3 cups rice');
    });

    test('ranges scale both ends', () {
      expect(scaleIngredientLine('4–5 скилидки чесън', 2), '8–10 скилидки чесън');
      expect(
        scaleIngredientLine('около 36-40 бр. бишкоти', 0.5),
        'около 18–20 бр. бишкоти',
      );
    });

    test('a decimal comma stays a comma', () {
      expect(scaleIngredientLine('1,5 кг картофи', 3), '4,5 кг картофи');
      expect(scaleIngredientLine('0,3 л вода', 0.5), '0,15 л вода');
    });

    test('lines without an amount are left alone', () {
      expect(scaleIngredientLine('сол и черен пипер на вкус', 2), 'сол и черен пипер на вкус');
      expect(scaleIngredientLine('ягоди', 2), 'ягоди');
    });

    test('factor one changes nothing', () {
      expect(scaleIngredientLine('1 1/2 cups milk', 1), '1 1/2 cups milk');
    });
  });

  test('formatAmount', () {
    expect(formatAmount(12.4), '12');
    expect(formatAmount(0.5), '½');
    expect(formatAmount(2.66), '2⅔');
    expect(formatAmount(0.97), '1');
    expect(formatAmount(1.2), '1.2');
    expect(formatAmount(1.2, comma: true), '1,2');
    expect(formatAmount(4.5, comma: true, decimal: true), '4,5');
    expect(formatAmount(3, decimal: true), '3');
  });
}
