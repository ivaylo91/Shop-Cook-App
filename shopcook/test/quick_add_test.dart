import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/features/shopping/product_category.dart';
import 'package:shopcook/features/shopping_lists/quick_add.dart';

void main() {
  group('starter items', () {
    for (final language in ['en', 'bg']) {
      for (final aisle in ProductCategory.values) {
        test('$language ${aisle.name} starters file under that aisle', () {
          // Added from an aisle's sheet, an item must show under that aisle
          // in shopping mode, or the sheet would be lying about it.
          for (final name in starterItems(aisle, language)) {
            expect(categorize(name), aisle, reason: name);
          }
        });
      }
    }
  });

  group('quickAddNames', () {
    test('the user\'s own come first, most bought first', () {
      final names = quickAddNames(
        aisle: ProductCategory.dairyAndEggs,
        history: [
          (name: 'Eggs', uses: 2),
          (name: 'Butter', uses: 9),
          (name: 'Bread', uses: 30), // another aisle
        ],
        starters: ['Milk', 'Eggs'],
      );
      expect(names, ['Butter', 'Eggs', 'Milk']);
    });

    test('a starter already in the history is not offered twice', () {
      final names = quickAddNames(
        aisle: ProductCategory.dairyAndEggs,
        history: [(name: 'milk', uses: 1)],
        starters: ['Milk', 'Yoghurt'],
      );
      expect(names, ['milk', 'Yoghurt']);
    });

    test('no more than the limit', () {
      final names = quickAddNames(
        aisle: ProductCategory.produce,
        history: const [],
        starters: [for (var i = 0; i < 40; i++) 'Apples $i'],
        limit: 24,
      );
      expect(names, hasLength(24));
    });
  });
}
