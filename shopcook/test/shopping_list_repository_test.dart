import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:shopcook/data/repositories/shopping_list_repository.dart';

void main() {
  late AppDatabase db;
  late ShoppingListRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ShoppingListRepository(db);
  });

  tearDown(() => db.close());

  /// Creates a list and returns its id.
  Future<String> aList([String name = 'Weekly']) async {
    await repo.createList(name);
    final lists = await repo.watchLists().first;
    return lists.single.id;
  }

  group('addOrMergeProduct', () {
    test('adds a new item', () async {
      final listId = await aList();

      final outcome = await repo.addOrMergeProduct(
        listId: listId,
        name: 'Onions',
        quantity: '2',
      );

      expect(outcome.didMerge, isFalse);
      final products = await repo.watchAllProducts(listId).first;
      expect(products.single.name, 'Onions');
    });

    test('tops up a matching unchecked item instead of duplicating it',
        () async {
      final listId = await aList();
      await repo.addOrMergeProduct(
        listId: listId,
        name: 'Onions',
        quantity: '2',
      );

      final outcome = await repo.addOrMergeProduct(
        listId: listId,
        name: 'onions',
        quantity: '3',
      );

      expect(outcome.didMerge, isTrue);
      final products = await repo.watchAllProducts(listId).first;
      expect(products.length, 1, reason: 'should not have created a second row');
      expect(products.single.quantity, '5');
    });

    test('keeps a separate row when the units cannot be added up', () async {
      final listId = await aList();
      await repo.addOrMergeProduct(
        listId: listId,
        name: 'Tomatoes',
        quantity: '500',
        unit: 'g',
      );

      // 2 tbsp of tomatoes is not 502 of anything.
      final outcome = await repo.addOrMergeProduct(
        listId: listId,
        name: 'Tomatoes',
        quantity: '2',
        unit: 'tbsp',
      );

      expect(outcome.didMerge, isFalse);
      final products = await repo.watchAllProducts(listId).first;
      expect(products.length, 2);
    });

    test('will not merge amounts it cannot read, like ranges', () async {
      final listId = await aList();
      await repo.addOrMergeProduct(
        listId: listId,
        name: 'Peppers',
        quantity: '2-3',
      );

      final outcome = await repo.addOrMergeProduct(
        listId: listId,
        name: 'Peppers',
        quantity: '1',
      );

      expect(outcome.didMerge, isFalse);
      final products = await repo.watchAllProducts(listId).first;
      expect(products.length, 2);
    });

    test('leaves a ticked item alone and adds a fresh row', () async {
      final listId = await aList();
      await repo.addOrMergeProduct(listId: listId, name: 'Milk');
      final first = (await repo.watchAllProducts(listId).first).single;
      await repo.toggleProductChecked(first.id, true);

      final outcome = await repo.addOrMergeProduct(
        listId: listId,
        name: 'Milk',
      );

      expect(outcome.didMerge, isFalse);
      final products = await repo.watchAllProducts(listId).first;
      expect(products.length, 2, reason: 'already-bought milk is not topped up');
    });

    test('does not merge across meals', () async {
      final listId = await aList();
      await repo.createMeal(listId, 'Bolognese');
      final meal = (await repo.watchMeals(listId).first).single;

      await repo.addOrMergeProduct(listId: listId, name: 'Onions');
      await repo.addOrMergeProduct(
        listId: listId,
        mealId: meal.id,
        name: 'Onions',
      );

      final products = await repo.watchAllProducts(listId).first;
      expect(products.length, 2, reason: 'the meal needs its own onion');
    });
  });

  group('undo', () {
    test('restores a deleted list with everything under it', () async {
      final listId = await aList('Weekend');
      await repo.createMeal(listId, 'Chilli');
      final meal = (await repo.watchMeals(listId).first).single;
      await repo.addOrMergeProduct(
        listId: listId,
        mealId: meal.id,
        name: 'Kidney beans',
      );
      await repo.addOrMergeProduct(listId: listId, name: 'Washing-up liquid');

      final deleted = await repo.deleteListWithUndo(listId);

      expect(await repo.watchLists().first, isEmpty);
      expect(deleted.meals.length, 1);
      expect(deleted.products.length, 2);

      await repo.undoDelete(deleted);

      expect((await repo.watchLists().first).single.name, 'Weekend');
      expect((await repo.watchMeals(listId).first).single.name, 'Chilli');
      expect((await repo.watchAllProducts(listId).first).length, 2);
    });

    test('restores a deleted meal and its ingredients', () async {
      final listId = await aList();
      await repo.createMeal(listId, 'Curry');
      final meal = (await repo.watchMeals(listId).first).single;
      await repo.addOrMergeProduct(
        listId: listId,
        mealId: meal.id,
        name: 'Coconut milk',
      );

      final deleted = await repo.deleteMealWithUndo(meal.id);

      expect(await repo.watchMeals(listId).first, isEmpty);
      // The FK cascade takes the ingredient with the meal.
      expect(await repo.watchAllProducts(listId).first, isEmpty);

      await repo.undoDelete(deleted);

      expect((await repo.watchMeals(listId).first).single.name, 'Curry');
      expect(
        (await repo.watchProductsForMeal(meal.id).first).single.name,
        'Coconut milk',
      );
    });

    test('restores a single deleted item', () async {
      final listId = await aList();
      await repo.addOrMergeProduct(listId: listId, name: 'Bread');
      final product = (await repo.watchAllProducts(listId).first).single;

      final deleted = await repo.deleteProductWithUndo(product.id);
      expect(await repo.watchAllProducts(listId).first, isEmpty);

      await repo.undoDelete(deleted);
      expect((await repo.watchAllProducts(listId).first).single.name, 'Bread');
    });
  });

  group('suggestions', () {
    test('rank the most-used names first and fold case together', () async {
      final listId = await aList();

      // Three separate lists' worth of history, so counts differ.
      for (final name in ['Milk', 'milk', 'MILK']) {
        await repo.addProduct(listId: listId, name: name);
      }
      await repo.addProduct(listId: listId, name: 'Bread');
      await repo.addProduct(listId: listId, name: 'Bread');
      await repo.addProduct(listId: listId, name: 'Capers');

      final suggestions = await repo.watchSuggestions().first;
      final names = suggestions.map((s) => s.name.toLowerCase()).toList();

      expect(names.take(3), ['milk', 'bread', 'capers']);
      expect(suggestions.first.uses, 3);
    });
  });
}
