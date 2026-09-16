import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class ShoppingLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Which signed-in user owns this list.
  ///
  /// Only lists carry an owner: meals, products and recipes are reachable
  /// only through a list, and every query for them is already scoped by a
  /// list id, so scoping lists scopes the whole tree.
  ///
  /// Nullable because rows written before this column existed have no owner
  /// yet. They are claimed by the first user to sign in after upgrading —
  /// see `claimUnownedLists`. A fresh row always has one.
  TextColumn get userId => text().nullable()();

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

  /// What this costs, in the user's own currency. Null means unpriced, which
  /// is different from free — a list total has to be able to say "so far".
  RealColumn get price => real().nullable()();

  /// An aisle the user put this in by hand, overriding the keyword guess.
  ///
  /// Stored as the enum's name rather than its index, so reordering
  /// [ProductCategory] cannot silently re-file everyone's groceries.
  TextColumn get categoryOverride => text().nullable()();

  /// Something you re-buy routinely, offered by the restock action.
  BoolColumn get isStaple => boolean().withDefault(const Constant(false))();

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

/// Cached recipe-search results.
///
/// A YouTube `search.list` call costs 100 of a 10,000-unit daily quota, and
/// both recipe screens search as soon as they open — so without this, merely
/// reopening the same item a hundred times in a day exhausts the key and
/// results stop coming back with no error to explain why.
///
/// Keyed by locale as well as query, because the search phrase is localised
/// and "пиле рецепта" and "chicken recipe" are not the same search.
@DataClassName('CachedSearch')
class RecipeSearches extends Table {
  /// Normalised: trimmed and lowercased by the repository.
  TextColumn get query => text()();
  TextColumn get locale => text()();

  /// The results as JSON, in the shape the search API returns them.
  TextColumn get payload => text()();

  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {query, locale};
}

@DriftDatabase(
  tables: [ShoppingLists, Meals, Products, Recipes, RecipeSearches],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

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
      // v3: lists belong to a user. Existing rows stay unowned here and are
      // claimed once someone signs in — the migration has no idea who that
      // is, and guessing would hand one user's lists to another.
      if (from < 3) {
        await m.addColumn(shoppingLists, shoppingLists.userId);
      }
      // v4: prices, a hand-set aisle, staples, and the search cache.
      if (from < 4) {
        await m.addColumn(products, products.price);
        await m.addColumn(products, products.categoryOverride);
        await m.addColumn(products, products.isStaple);
        await m.createTable(recipeSearches);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ShoppingLists
  Stream<List<ShoppingList>> watchLists(String userId) =>
      (select(shoppingLists)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Hands every ownerless list to [userId], and reports how many moved.
  ///
  /// Rows written before the owner column existed belong to whoever was using
  /// the device, which in practice is the first person to sign in after the
  /// upgrade. Doing it at sign-in rather than in the migration is what makes
  /// that safe: the migration cannot know who the user is.
  Future<int> claimUnownedLists(String userId) {
    return (update(shoppingLists)..where((t) => t.userId.isNull())).write(
      ShoppingListsCompanion(userId: Value(userId)),
    );
  }

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

  /// Sets or clears the price. Null clears it, which is why the companion
  /// takes an explicit Value rather than relying on absence.
  Future<void> setProductPrice(String id, double? price) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(price: Value(price)),
      );

  /// Files the product in [category] by hand, or clears the override so the
  /// keyword guess applies again.
  Future<void> setProductCategoryOverride(String id, String? category) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(categoryOverride: Value(category)),
      );

  Future<void> setProductStaple(String id, bool value) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(isStaple: Value(value)),
      );

  /// Every name the user has ever marked a staple, most recent first.
  ///
  /// Distinct by name, because a staple is a habit rather than one row: milk
  /// bought every week is many rows and one staple.
  Stream<List<StapleName>> watchStaples(String userId) {
    return customSelect(
      'SELECT p.name AS name, MAX(p.created_at) AS last_used '
      'FROM products p '
      'JOIN shopping_lists l ON l.id = p.list_id '
      'WHERE l.user_id = ? AND p.is_staple = 1 '
      'GROUP BY p.name COLLATE NOCASE '
      'ORDER BY last_used DESC',
      variables: [Variable.withString(userId)],
      readsFrom: {products, shoppingLists},
    ).watch().map(
      (rows) => rows
          .map((row) => StapleName(name: row.read<String>('name')))
          .toList(),
    );
  }

  /// Product names the user has added before, most-used first.
  ///
  /// Derived from the rows already on the lists rather than from a separate
  /// history table: the data is the history, and a second table would only
  /// have to be kept in sync with it.
  ///
  /// Joined through to the owning list, because this is the one query that
  /// reads across every list at once — without the join it would offer one
  /// user's shopping habits to another as suggestions.
  Stream<List<ProductSuggestion>> watchProductSuggestions(
    String userId, {
    int limit = 60,
  }) {
    return customSelect(
      'SELECT p.name AS name, COUNT(*) AS uses '
      'FROM products p '
      'JOIN shopping_lists l ON l.id = p.list_id '
      'WHERE l.user_id = ? '
      'GROUP BY p.name COLLATE NOCASE '
      'ORDER BY uses DESC, MAX(p.created_at) DESC '
      'LIMIT ?',
      variables: [Variable.withString(userId), Variable.withInt(limit)],
      readsFrom: {products, shoppingLists},
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

  // RecipeSearches
  Future<CachedSearch?> cachedSearch(String query, String locale) =>
      (select(recipeSearches)
            ..where((t) => t.query.equals(query) & t.locale.equals(locale)))
          .getSingleOrNull();

  Future<void> cacheSearch(RecipeSearchesCompanion entry) =>
      into(recipeSearches).insertOnConflictUpdate(entry);

  /// Drops cache rows older than [cutoff]. Called opportunistically rather
  /// than on a timer: there is no background work in this app, and a stale
  /// row costs nothing until someone asks for that query again.
  Future<int> pruneSearchCache(DateTime cutoff) =>
      (delete(recipeSearches)
            ..where((t) => t.fetchedAt.isSmallerThanValue(cutoff)))
          .go();

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

/// A staple, identified by name rather than by row.
class StapleName {
  final String name;

  const StapleName({required this.name});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'shopcook.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
