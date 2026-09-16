import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/core/money.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:shopcook/data/repositories/shopping_list_repository.dart';
import 'package:shopcook/features/shopping/product_category.dart';

void main() {
  late AppDatabase db;
  late ShoppingListRepository repo;

  const user = 'user-1';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ShoppingListRepository(db);
  });

  tearDown(() => db.close());

  Future<String> aList([String name = 'Weekly']) async {
    await repo.createList(name, userId: user);
    final lists = await repo.watchLists(user).first;
    return lists.firstWhere((l) => l.name == name).id;
  }

  Future<Product> only(String listId) async =>
      (await repo.watchAllProducts(listId).first).single;

  group('parsePrice', () {
    test('accepts either decimal separator', () {
      expect(parsePrice('2.40'), 2.40);
      expect(parsePrice('2,40'), 2.40);
    });

    test('tolerates stray spaces and empty input', () {
      expect(parsePrice(' 3 '), 3.0);
      expect(parsePrice('1 000'), 1000.0);
      expect(parsePrice(''), isNull);
      expect(parsePrice('   '), isNull);
    });

    test('rejects nonsense rather than guessing', () {
      expect(parsePrice('abc'), isNull);
      expect(parsePrice('2.4.0'), isNull);
      // A negative price is a typo, not a refund.
      expect(parsePrice('-5'), isNull);
    });
  });

  group('prices', () {
    test('a price can be set and cleared', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Milk');
      final product = await only(listId);

      expect(product.price, isNull, reason: 'unpriced, not zero');

      await repo.setPrice(product.id, 2.40);
      expect((await only(listId)).price, 2.40);

      await repo.setPrice(product.id, null);
      expect(
        (await only(listId)).price,
        isNull,
        reason: 'clearing has to be distinguishable from setting zero',
      );
    });

    test('zero is a real price, not the same as unpriced', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Free sample');
      await repo.setPrice((await only(listId)).id, 0);

      expect((await only(listId)).price, 0);
    });
  });

  group('aisleOf', () {
    test('falls back to the keyword guess with no override', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Мляко');

      expect(
        ShoppingListRepository.aisleOf(await only(listId)),
        ProductCategory.dairyAndEggs,
      );
    });

    test('a hand-set aisle wins over the guess', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Мляко');

      await repo.setAisle(
        userId: user,
        name: 'Мляко',
        category: ProductCategory.frozen,
      );

      expect(
        ShoppingListRepository.aisleOf(await only(listId)),
        ProductCategory.frozen,
      );
    });

    test('clearing the override restores the guess', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Мляко');
      await repo.setAisle(
        userId: user,
        name: 'Мляко',
        category: ProductCategory.frozen,
      );

      await repo.setAisle(userId: user, name: 'Мляко', category: null);

      expect(
        ShoppingListRepository.aisleOf(await only(listId)),
        ProductCategory.dairyAndEggs,
      );
    });

    test('a correction applies to every row with that name', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Халуми');
      await repo.addProduct(listId: listId, name: 'халуми');

      await repo.setAisle(
        userId: user,
        name: 'халуми',
        category: ProductCategory.dairyAndEggs,
      );

      final products = await repo.watchAllProducts(listId).first;
      expect(products.length, 2);
      for (final product in products) {
        expect(
          ShoppingListRepository.aisleOf(product),
          ProductCategory.dairyAndEggs,
          reason: 'case should not split one correction into two',
        );
      }
    });

    test('a new item inherits a correction made earlier', () async {
      final first = await aList('Week one');
      await repo.addProduct(listId: first, name: 'Халуми');
      await repo.setAisle(
        userId: user,
        name: 'Халуми',
        category: ProductCategory.dairyAndEggs,
      );

      // Next week, a fresh list and a fresh row.
      final second = await aList('Week two');
      await repo.addProduct(
        listId: second,
        name: 'Халуми',
        userId: user,
      );

      expect(
        ShoppingListRepository.aisleOf(await only(second)),
        ProductCategory.dairyAndEggs,
        reason: 'fixing it once should fix it for future shops',
      );
    });

    test('an unknown stored aisle degrades to the guess', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Мляко');
      final product = await only(listId);

      // As a row written by a build that had a category this one does not.
      await db.setProductCategoryOverride(product.id, 'notAnAisle');

      expect(
        ShoppingListRepository.aisleOf(await only(listId)),
        ProductCategory.dairyAndEggs,
        reason: 'a name that no longer exists must not crash or vanish',
      );
    });
  });

  // SQLite's NOCASE collation and lower() fold ASCII only, so every
  // case-insensitive name comparison used to fail for Cyrillic: duplicates
  // were never merged, "Мляко" and "мляко" showed as two habits, and an aisle
  // correction only reached the row you were looking at. Folding moved into
  // Dart; these pin it down.
  group('case folding is not ASCII-only', () {
    test('duplicate merging folds Cyrillic case', () async {
      final listId = await aList();
      await repo.addOrMergeProduct(
        listId: listId,
        name: 'Мляко',
        quantity: '1',
      );

      final outcome = await repo.addOrMergeProduct(
        listId: listId,
        name: 'мляко',
        quantity: '2',
      );

      expect(outcome.didMerge, isTrue);
      final products = await repo.watchAllProducts(listId).first;
      expect(products.length, 1, reason: 'lower() would have missed this');
      expect(products.single.quantity, '3');
    });

    test('suggestions fold Cyrillic case into one habit', () async {
      final listId = await aList();
      for (final spelling in ['Мляко', 'мляко', 'МЛЯКО']) {
        await repo.addProduct(listId: listId, name: spelling);
      }
      await repo.addProduct(listId: listId, name: 'Хляб');

      final suggestions = await repo.watchSuggestions(user).first;

      expect(suggestions.length, 2);
      expect(suggestions.first.uses, 3);
      expect(foldName(suggestions.first.name), 'мляко');
    });

    test('staples fold Cyrillic case', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Мляко');
      await repo.addProduct(listId: listId, name: 'мляко');
      for (final p in await repo.watchAllProducts(listId).first) {
        await repo.setStaple(p.id, true);
      }

      expect(
        (await repo.watchStaples(user).first).length,
        1,
        reason: 'one habit, not two spellings',
      );
    });
  });

  group('staples', () {
    test('restock adds staples that are missing', () async {
      final first = await aList('Week one');
      await repo.addProduct(listId: first, name: 'Мляко');
      await repo.addProduct(listId: first, name: 'Хляб');
      for (final p in await repo.watchAllProducts(first).first) {
        await repo.setStaple(p.id, true);
      }

      final second = await aList('Week two');
      final added = await repo.restockStaples(listId: second, userId: user);

      expect(added, 2);
      final names = (await repo.watchAllProducts(second).first)
          .map((p) => p.name)
          .toSet();
      expect(names, {'Мляко', 'Хляб'});
    });

    test('restock skips what is already on the list', () async {
      final listId = await aList();
      await repo.addProduct(listId: listId, name: 'Мляко');
      await repo.setStaple((await only(listId)).id, true);

      final added = await repo.restockStaples(listId: listId, userId: user);

      expect(added, 0, reason: 'the staple is already there');
      expect((await repo.watchAllProducts(listId).first).length, 1);
    });

    test('staples are per user', () async {
      final mine = await aList('Mine');
      await repo.addProduct(listId: mine, name: 'Мляко');
      await repo.setStaple((await only(mine)).id, true);

      expect((await repo.watchStaples(user).first).length, 1);
      expect(await repo.watchStaples('someone-else').first, isEmpty);
    });
  });
}
