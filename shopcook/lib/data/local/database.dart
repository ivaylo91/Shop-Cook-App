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
  int get schemaVersion => 1;

  /// SQLite disables foreign keys per connection by default, which silently
  /// makes every `onDelete: KeyAction.cascade` above a no-op — deleting a list
  /// or meal would leave its products and recipes behind as unreachable rows
  /// that still count toward the shopping progress. Turn them on at open.
  @override
  MigrationStrategy get migration => MigrationStrategy(
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

  // Meals
  Stream<List<Meal>> watchMealsForList(String listId) =>
      (select(meals)
        ..where((t) => t.listId.equals(listId))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Future<void> insertMeal(MealsCompanion entry) => into(meals).insert(entry);

  Future<void> deleteMeal(String id) =>
      (delete(meals)..where((t) => t.id.equals(id))).go();

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

  Future<void> deleteProduct(String id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

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

  Future<void> deleteRecipe(String id) =>
      (delete(recipes)..where((t) => t.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'shopcook.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
