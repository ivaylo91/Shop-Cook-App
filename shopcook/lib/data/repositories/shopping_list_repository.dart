import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';

const _uuid = Uuid();

class ShoppingListRepository {
  final AppDatabase _db;

  ShoppingListRepository(this._db);

  Stream<List<ShoppingList>> watchLists() => _db.watchLists();

  Future<void> createList(String name) {
    return _db.insertList(
      ShoppingListsCompanion.insert(
        id: _uuid.v4(),
        name: name,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteList(String id) => _db.deleteList(id);

  Stream<List<Meal>> watchMeals(String listId) =>
      _db.watchMealsForList(listId);

  Future<void> createMeal(String listId, String name) {
    return _db.insertMeal(
      MealsCompanion.insert(
        id: _uuid.v4(),
        listId: listId,
        name: name,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteMeal(String id) => _db.deleteMeal(id);

  Stream<List<Product>> watchUnassignedProducts(String listId) =>
      _db.watchUnassignedProducts(listId);

  /// Every product in the list, whether or not it belongs to a meal.
  Stream<List<Product>> watchAllProducts(String listId) =>
      _db.watchProductsForList(listId);

  Stream<List<Product>> watchProductsForMeal(String mealId) =>
      _db.watchProductsForMeal(mealId);

  Future<void> addProduct({
    required String listId,
    String? mealId,
    required String name,
    String quantity = '',
    String unit = '',
  }) {
    return _db.insertProduct(
      ProductsCompanion.insert(
        id: _uuid.v4(),
        listId: listId,
        mealId: Value(mealId),
        name: name,
        quantity: Value(quantity),
        unit: Value(unit),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> toggleProductChecked(String id, bool value) =>
      _db.toggleChecked(id, value);

  Future<void> moveProductToMeal(String productId, String? mealId) =>
      _db.setProductMeal(productId, mealId);

  Future<void> deleteProduct(String id) => _db.deleteProduct(id);
}
