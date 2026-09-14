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

  Future<void> renameList(String id, String name) =>
      _db.renameList(id, name.trim());

  Future<void> deleteList(String id) => _db.deleteList(id);

  /// Deletes a list and hands back everything it took with it.
  ///
  /// Deleting a list cascades through its meals, products and recipes, so an
  /// undo has to put the whole subtree back. Reading it first is what makes
  /// the undo possible without a soft-delete column.
  Future<DeletedTree> deleteListWithUndo(String id) async {
    final list = await _db.listById(id);
    final meals = await _db.mealsForList(id);
    final products = await _db.productsForList(id);
    final recipes = await _db.recipesForMeals([for (final m in meals) m.id]);

    await _db.deleteList(id);

    return DeletedTree(
      list: list,
      meals: meals,
      products: products,
      recipes: recipes,
    );
  }

  /// Deletes a meal, keeping its ingredients and recipes for an undo.
  Future<DeletedTree> deleteMealWithUndo(String id) async {
    final meal = await _db.mealById(id);
    final products = await _db.watchProductsForMeal(id).first;
    final recipes = await _db.recipesForMeals([id]);

    await _db.deleteMeal(id);

    return DeletedTree(
      meals: meal == null ? const [] : [meal],
      products: products,
      recipes: recipes,
    );
  }

  Future<DeletedTree> deleteProductWithUndo(String id) async {
    final product = await _db.productById(id);
    await _db.deleteProduct(id);
    return DeletedTree(products: product == null ? const [] : [product]);
  }

  Future<void> undoDelete(DeletedTree tree) => _db.restoreTree(
    list: tree.list,
    meals: tree.meals,
    products: tree.products,
    recipes: tree.recipes,
  );

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

  Future<void> renameMeal(String id, String name) =>
      _db.renameMeal(id, name.trim());

  /// Names the user has added before, most-used first.
  Stream<List<ProductSuggestion>> watchSuggestions() =>
      _db.watchProductSuggestions();

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

  /// Adds several products at once, as when importing a recipe.
  Future<void> addProducts({
    required String listId,
    String? mealId,
    required List<({String name, String quantity, String unit})> items,
  }) {
    final now = DateTime.now();
    return _db.insertProducts([
      for (final (index, item) in items.indexed)
        ProductsCompanion.insert(
          id: _uuid.v4(),
          listId: listId,
          mealId: Value(mealId),
          name: item.name,
          quantity: Value(item.quantity),
          unit: Value(item.unit),
          // Nudge each timestamp so the list keeps the recipe's own order.
          createdAt: now.add(Duration(milliseconds: index)),
        ),
    ]);
  }

  /// Adds an item, or tops up the matching one already on the list.
  ///
  /// Two recipes both wanting onions used to produce two rows, and shopping
  /// mode showed both. Returns what happened so the caller can say so.
  Future<AddOutcome> addOrMergeProduct({
    required String listId,
    String? mealId,
    required String name,
    String quantity = '',
    String unit = '',
  }) async {
    final existing = await _db.findMergeTarget(
      listId: listId,
      mealId: mealId,
      name: name,
    );

    if (existing == null) {
      await addProduct(
        listId: listId,
        mealId: mealId,
        name: name,
        quantity: quantity,
        unit: unit,
      );
      return const AddOutcome.added();
    }

    final merged = _mergeQuantities(
      existingQuantity: existing.quantity,
      existingUnit: existing.unit,
      addedQuantity: quantity,
      addedUnit: unit,
    );

    if (merged == null) {
      // Units that cannot be added up (2 tbsp onto 500 g) are better left as
      // two honest rows than silently combined into a wrong number.
      await addProduct(
        listId: listId,
        mealId: mealId,
        name: name,
        quantity: quantity,
        unit: unit,
      );
      return const AddOutcome.added();
    }

    await _db.setProductQuantity(existing.id, merged);
    return AddOutcome.merged(name: existing.name, quantity: merged, unit: existing.unit);
  }

  /// Sums two amounts when that is unambiguous, else null.
  ///
  /// Only numeric amounts in the same unit are added. Anything else — a range
  /// ("2-3"), a pack multiplier ("2 × 400g"), a fraction, mismatched units —
  /// returns null so the caller keeps them apart.
  static String? _mergeQuantities({
    required String existingQuantity,
    required String existingUnit,
    required String addedQuantity,
    required String addedUnit,
  }) {
    if (existingUnit.trim().toLowerCase() != addedUnit.trim().toLowerCase()) {
      return null;
    }

    final a = _plainNumber(existingQuantity);
    final b = _plainNumber(addedQuantity);

    // An empty amount means "just get some", which stays that way.
    if (existingQuantity.trim().isEmpty && addedQuantity.trim().isEmpty) {
      return '';
    }
    if (a == null || b == null) return null;

    final sum = a + b;
    return sum == sum.roundToDouble()
        ? sum.round().toString()
        : sum.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static double? _plainNumber(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return null;
    return double.tryParse(text);
  }

  Future<void> toggleProductChecked(String id, bool value) =>
      _db.toggleChecked(id, value);

  Future<void> moveProductToMeal(String productId, String? mealId) =>
      _db.setProductMeal(productId, mealId);

  Future<void> deleteProduct(String id) => _db.deleteProduct(id);
}

/// Rows removed by a delete, kept in memory just long enough for the undo
/// snackbar to be able to put them back.
class DeletedTree {
  final ShoppingList? list;
  final List<Meal> meals;
  final List<Product> products;
  final List<Recipe> recipes;

  const DeletedTree({
    this.list,
    this.meals = const [],
    this.products = const [],
    this.recipes = const [],
  });

  bool get isEmpty =>
      list == null && meals.isEmpty && products.isEmpty && recipes.isEmpty;
}

/// Whether an add created a row or topped up an existing one.
class AddOutcome {
  final bool didMerge;
  final String? name;
  final String? quantity;
  final String? unit;

  const AddOutcome.added()
    : didMerge = false,
      name = null,
      quantity = null,
      unit = null;

  const AddOutcome.merged({
    required this.name,
    required this.quantity,
    required this.unit,
  }) : didMerge = true;

  /// e.g. "Onions is now 3" — what to tell the user after a merge.
  String get mergeMessage {
    final amount = '${quantity ?? ''} ${unit ?? ''}'.trim();
    return amount.isEmpty
        ? 'Already on the list — $name'
        : '$name is now $amount';
  }
}
