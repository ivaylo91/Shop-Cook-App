import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class ShoppingLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// The day this meal is meant to be cooked, or null while it is only an
  /// idea. Date-only in intent: stored at midnight local time so two meals on
  /// the same day compare equal.
  DateTimeColumn get plannedFor => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get mealId =>
      text().nullable().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get quantity => text().withDefault(const Constant(''))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

enum RecipeSourceType { video, web }

class Recipes extends Table {
  TextColumn get id => text()();
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get thumbnailUrl => text().withDefault(const Constant(''))();
  TextColumn get sourceType =>
      textEnum<RecipeSourceType>().withDefault(
        Constant(RecipeSourceType.web.name),
      )();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ShoppingLists, Meals, Products, Recipes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  /// The migration ladder. Every step has to be additive and idempotent in
  /// order, because an install can be on any earlier version — a phone that
  /// skipped a release upgrades straight from 1 to the current version by
  /// running each step in turn.
  ///
  /// `beforeOpen` runs on every open, not just on upgrades: SQLite disables
  /// foreign keys per connection by default, which silently makes every
  /// `onDelete: KeyAction.cascade` above a no-op — deleting a list or meal
  /// would leave its products and recipes behind as unreachable rows that
  /// still count toward the shopping progress.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2: meals can be planned for a day.
      if (from < 2) {
        await m.addColumn(meals, meals.plannedFor);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ShoppingLists
  Stream<List<ShoppingList>> watchLists() =>
      (select(shoppingLists)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<void> insertList(ShoppingListsCompanion entry) =>
      into(shoppingLists).insert(entry);

  Future<void> deleteList(String id) =>
      (delete(shoppingLists)..where((t) => t.id.equals(id))).go();

  Future<void> renameList(String id, String name) =>
      (update(shoppingLists)..where((t) => t.id.equals(id))).write(
        ShoppingListsCompanion(name: Value(name)),
      );

  /// One-shot read, for snapshotting a list before it is deleted.
  Future<ShoppingList?> listById(String id) =>
      (select(shoppingLists)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  // Meals
  Stream<List<Meal>> watchMealsForList(String listId) =>
      (select(meals)
        ..where((t) => t.listId.equals(listId))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<void> insertMeal(MealsCompanion entry) => into(meals).insert(entry);

  Future<void> insertMeals(List<MealsCompanion> entries) =>
      batch((b) => b.insertAll(meals, entries));

  Future<void> deleteMeal(String id) =>
      (delete(meals)..where((t) => t.id.equals(id))).go();

  Future<void> renameMeal(String id, String name) =>
      (update(meals)..where((t) => t.id.equals(id))).write(
        MealsCompanion(name: Value(name)),
      );

  Future<Meal?> mealById(String id) =>
      (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Meal>> mealsForList(String listId) =>
      (select(meals)..where((t) => t.listId.equals(listId))).get();

  /// Every planned meal in a half-open date range, across all lists — the
  /// week view is not scoped to one shopping list, because a week is not.
  Stream<List<Meal>> watchMealsPlannedBetween(DateTime from, DateTime to) =>
      (select(meals)
            ..where(
              (t) =>
                  t.plannedFor.isBiggerOrEqualValue(from) &
                  t.plannedFor.isSmallerThanValue(to),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.plannedFor),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  /// Meals that are still just ideas, newest first.
  Stream<List<Meal>> watchUnplannedMeals() =>
      (select(meals)
            ..where((t) => t.plannedFor.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> setMealPlannedFor(String id, DateTime? day) =>
      (update(meals)..where((t) => t.id.equals(id))).write(
        MealsCompanion(plannedFor: Value(day)),
      );

  // Products
  Stream<List<Product>> watchProductsForList(String listId) =>
      (select(products)
        ..where((t) => t.listId.equals(listId))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Stream<List<Product>> watchProductsForMeal(String mealId) =>
      (select(products)
        ..where((t) => t.mealId.equals(mealId))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Stream<List<Product>> watchUnassignedProducts(String listId) =>
      (select(products)
        ..where((t) => t.listId.equals(listId) & t.mealId.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<void> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry);

  /// One transaction for a whole recipe's worth of ingredients.
  Future<void> insertProducts(List<ProductsCompanion> entries) =>
      batch((b) => b.insertAll(products, entries));

  Future<void> deleteProduct(String id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  Future<List<Product>> productsForList(String listId) =>
      (select(products)..where((t) => t.listId.equals(listId))).get();

  Future<Product?> productById(String id) =>
      (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// An unchecked item in the same place with the same name, ignoring case —
  /// the row a new add should top up rather than duplicate.
  ///
  /// Scoped to [mealId] so "onion" for the bolognese and "onion" on the loose
  /// list stay separate; merging across meals would misreport what a meal
  /// needs.
  Future<Product?> findMergeTarget({
    required String listId,
    required String? mealId,
    required String name,
  }) {
    final query = select(products)
      ..where(
        (t) =>
            t.listId.equals(listId) &
            (mealId == null ? t.mealId.isNull() : t.mealId.equals(mealId)) &
            t.isChecked.equals(false) &
            t.name.lower().equals(name.toLowerCase().trim()),
      )
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> setProductQuantity(String id, String quantity) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(quantity: Value(quantity)),
      );

  /// Product names the user has added before, most-used first.
  ///
  /// Derived from the rows already on the lists rather than from a separate
  /// history table: the data is the history, and a second table would only
  /// have to be kept in sync with it.
  Stream<List<ProductSuggestion>> watchProductSuggestions({int limit = 60}) {
    return customSelect(
      'SELECT name, COUNT(*) AS uses FROM products '
      'GROUP BY name COLLATE NOCASE '
      'ORDER BY uses DESC, MAX(created_at) DESC '
      'LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {products},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => ProductSuggestion(
              name: row.read<String>('name'),
              uses: row.read<int>('uses'),
            ),
          )
          .toList(),
    );
  }

  /// Moves a product into [mealId], or back onto the list itself when null.
  Future<void> setProductMeal(String id, String? mealId) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(mealId: Value(mealId)),
      );

  Future<void> toggleChecked(String id, bool value) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(isChecked: Value(value)),
      );

  // Recipes
  Stream<List<Recipe>> watchRecipesForMeal(String mealId) =>
      (select(recipes)
        ..where((t) => t.mealId.equals(mealId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<void> insertRecipe(RecipesCompanion entry) =>
      into(recipes).insert(entry);

  Future<void> insertRecipes(List<RecipesCompanion> entries) =>
      batch((b) => b.insertAll(recipes, entries));

  Future<void> deleteRecipe(String id) =>
      (delete(recipes)..where((t) => t.id.equals(id))).go();

  Future<List<Recipe>> recipesForMeals(List<String> mealIds) {
    if (mealIds.isEmpty) return Future.value(const []);
    return (select(recipes)..where((t) => t.mealId.isIn(mealIds))).get();
  }

  /// Re-inserts a whole deleted subtree in foreign-key order, as one
  /// transaction so a failure part-way cannot leave orphans behind.
  Future<void> restoreTree({
    ShoppingList? list,
    List<Meal> meals = const [],
    List<Product> products = const [],
    List<Recipe> recipes = const [],
  }) {
    return transaction(() async {
      if (list != null) await into(shoppingLists).insert(list);
      for (final meal in meals) {
        await into(this.meals).insert(meal);
      }
      for (final product in products) {
        await into(this.products).insert(product);
      }
      for (final recipe in recipes) {
        await into(this.recipes).insert(recipe);
      }
    });
  }
}

/// A name the user has typed before, with how often, for the composer's
/// suggestions.
class ProductSuggestion {
  final String name;
  final int uses;

  const ProductSuggestion({required this.name, required this.uses});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'shopcook.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
