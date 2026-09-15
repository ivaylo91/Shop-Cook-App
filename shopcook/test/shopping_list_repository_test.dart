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

  const user = 'user-1';
  const otherUser = 'user-2';

  /// Creates a list owned by [owner] and returns its id.
  Future<String> aList([String name = 'Weekly', String owner = user]) async {
    await repo.createList(name, userId: owner);
    final lists = await repo.watchLists(owner).first;
    return lists.firstWhere((l) => l.name == name).id;
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

      expect(await repo.watchLists(user).first, isEmpty);
      expect(deleted.meals.length, 1);
      expect(deleted.products.length, 2);

      await repo.undoDelete(deleted);

      expect((await repo.watchLists(user).first).single.name, 'Weekend');
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

  group('per-user scoping', () {
    test('one user does not see another user\'s lists', () async {
      await aList('Mine', user);
      await aList('Theirs', otherUser);

      final mine = await repo.watchLists(user).first;
      final theirs = await repo.watchLists(otherUser).first;

      expect(mine.map((l) => l.name), ['Mine']);
      expect(theirs.map((l) => l.name), ['Theirs']);
    });

    test('suggestions do not leak across users', () async {
      final mineId = await aList('Mine', user);
      final theirsId = await aList('Theirs', otherUser);

      await repo.addProduct(listId: mineId, name: 'Marmite');
      await repo.addProduct(listId: theirsId, name: 'Anchovies');

      final mine = await repo.watchSuggestions(user).first;
      final theirs = await repo.watchSuggestions(otherUser).first;

      expect(mine.map((s) => s.name), ['Marmite']);
      expect(theirs.map((s) => s.name), ['Anchovies']);
    });

    test('claiming hands ownerless lists to the signing-in user', () async {
      // A list as it exists on a device upgraded from before lists had
      // owners: written straight to the table with no user.
      await db.insertList(
        ShoppingListsCompanion.insert(
          id: 'legacy',
          name: 'From before',
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      expect(
        await repo.watchLists(user).first,
        isEmpty,
        reason: 'an unowned list belongs to nobody until it is claimed',
      );

      final claimed = await repo.claimUnownedLists(user);

      expect(claimed, 1);
      expect((await repo.watchLists(user).first).single.name, 'From before');
      expect(await repo.watchLists(otherUser).first, isEmpty);
    });

    test('claiming twice does not take the first user\'s lists', () async {
      await db.insertList(
        ShoppingListsCompanion.insert(
          id: 'legacy',
          name: 'From before',
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await repo.claimUnownedLists(user);
      final second = await repo.claimUnownedLists(otherUser);

      expect(second, 0, reason: 'nothing is left unowned');
      expect((await repo.watchLists(user).first).single.name, 'From before');
      expect(await repo.watchLists(otherUser).first, isEmpty);
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

      final suggestions = await repo.watchSuggestions(user).first;
      final names = suggestions.map((s) => s.name.toLowerCase()).toList();

      expect(names.take(3), ['milk', 'bread', 'capers']);
      expect(suggestions.first.uses, 3);
    });
  });
}
