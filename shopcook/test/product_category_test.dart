import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/features/shopping/product_category.dart';

void main() {
  group('categorize', () {
    test('matches a plain product name', () {
      expect(categorize('Bread'), ProductCategory.bakery);
      expect(categorize('Bacon'), ProductCategory.meatAndFish);
      expect(categorize('Parmesan'), ProductCategory.dairyAndEggs);
    });

    test('is case insensitive and tolerates plurals', () {
      expect(categorize('BANANAS'), ProductCategory.produce);
      expect(categorize('eggs'), ProductCategory.dairyAndEggs);
    });

    test('prefers the head noun over an earlier modifier', () {
      // "orange" is produce and longer than "juice", so a plain
      // longest-match would file this under produce.
      expect(categorize('Orange Juice'), ProductCategory.drinks);
      expect(categorize('Ground Beef'), ProductCategory.meatAndFish);
      expect(categorize('Dish Soap'), ProductCategory.household);
    });

    test('multi-word keywords beat the single words inside them', () {
      expect(categorize('Tomato Paste'), ProductCategory.pantry);
      expect(categorize('Ice Cream'), ProductCategory.frozen);
      expect(categorize('Peanut Butter'), ProductCategory.pantry);
      expect(categorize('Black Pepper'), ProductCategory.pantry);
    });

    test('still reads the whole name when the head noun is unknown', () {
      expect(categorize('Frozen Peas'), ProductCategory.frozen);
    });

    test('files tomato products by what they actually are', () {
      expect(categorize('Tomato purée'), ProductCategory.pantry);
      expect(categorize('Tomato paste'), ProductCategory.pantry);
      expect(categorize('Cherry tomatoes'), ProductCategory.produce);
    });

    test('keeps related products apart', () {
      expect(categorize('Sour Cream'), ProductCategory.dairyAndEggs);
      expect(categorize('Red Bell Pepper'), ProductCategory.produce);
    });

    test('matches whole words, not letters inside them', () {
      // "bunch" contains "bun", which used to file this under Bakery.
      expect(
        categorize('Small bunch of coriander leaves'),
        isNot(ProductCategory.bakery),
      );
      // "grape" inside "grapefruit" and "corn" inside "cornflour" likewise.
      expect(categorize('Cornflour'), isNot(ProductCategory.produce));
    });

    test('still reads plurals and compounds', () {
      expect(categorize('Bananas'), ProductCategory.produce);
      expect(categorize('Tomatoes'), ProductCategory.produce);
      expect(categorize('Buttermilk'), ProductCategory.dairyAndEggs);
      expect(categorize('Chicken thighs'), ProductCategory.meatAndFish);
    });

    test('falls back to other for anything unrecognised', () {
      expect(categorize('Batteries'), ProductCategory.other);
      expect(categorize(''), ProductCategory.other);
    });
  });
}
