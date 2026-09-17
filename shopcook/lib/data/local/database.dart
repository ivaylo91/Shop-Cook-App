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

/// A saved recipe, owned by a user rather than by a meal.
///
/// Until v5 a recipe belonged to exactly one meal and cascaded with it, so
/// finishing a meal destroyed the recipe you had found for it. Now recipes are
/// a library and meals link to them through [MealRecipes]: the bolognese you
/// cook every other week is one row, used by many meals.
class Recipes extends Table {
  TextColumn get id => text()();

  /// Nullable for the same reason as [ShoppingLists.userId]: rows migrated
  /// from before ownership existed are claimed at the next sign-in.
  TextColumn get userId => text().nullable()();

  TextColumn get title => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get thumbnailUrl => text().withDefault(const Constant(''))();
  TextColumn get sourceType =>
      textEnum<RecipeSourceType>().withDefault(
        Constant(RecipeSourceType.web.name),
      )();
  DateTimeColumn get createdAt => dateTime()();

  /// The page's ingredients and method as last read by the importer, as
  /// JSON. Kept so cooking mode works in a kitchen with no signal; null
  /// until the page has been read once.
  TextColumn get details => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Which meals use which saved recipes.
///
/// Deleting a meal removes its links and nothing else; deleting a recipe
/// removes it from every meal.
@DataClassName('MealRecipe')
class MealRecipes extends Table {
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {mealId, recipeId};
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
  tables: [
    ShoppingLists,
    Meals,
    Products,
    Recipes,
    MealRecipes,
    RecipeSearches,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
      // v5: recipes become a per-user library linked to meals, instead of
      // belonging to (and dying with) a single meal. Order matters: the old
      // meal_id is read twice before the rebuild drops it.
      if (from < 5) {
        await m.createTable(mealRecipes);
        await m.addColumn(recipes, recipes.userId);

        // 1. Every existing attachment becomes a link.
        await customStatement(
          'INSERT OR IGNORE INTO meal_recipes (meal_id, recipe_id, created_at) '
          'SELECT meal_id, id, created_at FROM recipes '
          'WHERE meal_id IS NOT NULL',
        );

        // 2. A recipe is owned by whoever owned the list its meal was on.
        //    Null when that list is itself still unowned; the sign-in claim
        //    picks those up.
        await customStatement(
          'UPDATE recipes SET user_id = ('
          '  SELECT l.user_id FROM meals m '
          '  JOIN shopping_lists l ON l.id = m.list_id '
          '  WHERE m.id = recipes.meal_id'
          ')',
        );

        // 3. Rebuild without meal_id, using SQLite's create-copy-drop-rename
        //    procedure. The DDL is written out rather than derived from the
        //    Recipes class on purpose: a migration step has to keep doing
        //    exactly what it did on the day it shipped, and a generated
        //    rebuild would silently change whenever Recipes did. Foreign keys
        //    are still off here — beforeOpen turns them on after migrating —
        //    which the rebuild procedure requires.
        await customStatement(
          'CREATE TABLE recipes_v5 ('
          'id TEXT NOT NULL, '
          'user_id TEXT NULL, '
          'title TEXT NOT NULL, '
          'source_url TEXT NOT NULL, '
          "thumbnail_url TEXT NOT NULL DEFAULT '', "
          "source_type TEXT NOT NULL DEFAULT 'web', "
          'created_at INTEGER NOT NULL, '
          'PRIMARY KEY (id))',
        );
        await customStatement(
          'INSERT INTO recipes_v5 (id, user_id, title, source_url, '
          'thumbnail_url, source_type, created_at) '
          'SELECT id, user_id, title, source_url, thumbnail_url, '
          'source_type, created_at FROM recipes',
        );
        await customStatement('DROP TABLE recipes');
        await customStatement('ALTER TABLE recipes_v5 RENAME TO recipes');
      }
      // v6: a cached copy of each recipe page's ingredients and method.
      if (from < 6) {
        await m.addColumn(recipes, recipes.details);
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
    return transaction(() async {
      // Recipes migrated alongside unowned lists are unowned too, and belong
      // to the same person.
      await (update(recipes)..where((t) => t.userId.isNull())).write(
        RecipesCompanion(userId: Value(userId)),
      );
      return (update(shoppingLists)..where((t) => t.userId.isNull())).write(
        ShoppingListsCompanion(userId: Value(userId)),
      );
    });
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

  /// Every meal of [userId], newest first, with the name of its list — for
  /// picking which meal a library recipe should go on.
  Future<List<({Meal meal, String listName})>> mealsForUser(
    String userId,
  ) async {
    final query = select(meals).join([
      innerJoin(shoppingLists, shoppingLists.id.equalsExp(meals.listId)),
    ])
      ..where(shoppingLists.userId.equals(userId))
      ..orderBy([OrderingTerm.desc(meals.createdAt)]);

    return [
      for (final row in await query.get())
        (
          meal: row.readTable(meals),
          listName: row.readTable(shoppingLists).name,
        ),
    ];
  }

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

  /// Every product belonging to [userId], across all their lists.
  ///
  /// The basis for the queries that have to reason across lists — suggestions
  /// and staples — which then group in Dart so case folding is correct for
  /// non-ASCII names.
  Stream<List<Product>> watchAllProductsForUser(String userId) {
    final query = select(products).join([
      innerJoin(shoppingLists, shoppingLists.id.equalsExp(products.listId)),
    ])..where(shoppingLists.userId.equals(userId));

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(products)).toList(),
    );
  }

  Future<List<Product>> productsForUser(String userId) =>
      watchAllProductsForUser(userId).first;

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
  }) async {
    // Narrowed in SQL, matched in Dart: `lower()` in SQLite would leave a
    // Cyrillic name untouched while the bound parameter arrived folded, so
    // nothing would ever match and every add would duplicate.
    final candidates = await (select(products)..where(
      (t) =>
          t.listId.equals(listId) &
          (mealId == null ? t.mealId.isNull() : t.mealId.equals(mealId)) &
          t.isChecked.equals(false),
    )).get();

    final needle = foldName(name);
    for (final candidate in candidates) {
      if (foldName(candidate.name) == needle) return candidate;
    }
    return null;
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

  /// The aisle this user last filed [name] in by hand, if ever.
  ///
  /// Corrections are remembered by name rather than by row, so fixing
  /// "halloumi" once fixes it for every future shop instead of only for the
  /// row in front of you.
  Future<String?> rememberedCategory({
    required String userId,
    required String name,
  }) async {
    final needle = foldName(name);
    if (needle.isEmpty) return null;

    final matches =
        (await productsForUser(userId))
            .where((p) => p.categoryOverride != null)
            .where((p) => foldName(p.name) == needle)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return matches.isEmpty ? null : matches.first.categoryOverride;
  }

  /// Applies an aisle to every row with this name, so a correction is not
  /// only about the one in front of you.
  Future<int> setCategoryOverrideByName({
    required String userId,
    required String name,
    required String? category,
  }) async {
    final needle = foldName(name);
    if (needle.isEmpty) return 0;

    final ids = [
      for (final product in await productsForUser(userId))
        if (foldName(product.name) == needle) product.id,
    ];
    if (ids.isEmpty) return 0;

    await (update(products)..where((t) => t.id.isIn(ids))).write(
      ProductsCompanion(categoryOverride: Value(category)),
    );

    return ids.length;
  }

  Future<void> setProductStaple(String id, bool value) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(isStaple: Value(value)),
      );

  /// Every name the user has ever marked a staple, most recent first.
  ///
  /// Distinct by name, because a staple is a habit rather than one row: milk
  /// bought every week is many rows and one staple.
  Stream<List<StapleName>> watchStaples(String userId) {
    return watchAllProductsForUser(userId).map((rows) {
      final lastUsed = <String, DateTime>{};
      final display = <String, String>{};

      for (final product in rows.where((p) => p.isStaple)) {
        final key = foldName(product.name);
        if (key.isEmpty) continue;

        final seen = lastUsed[key];
        if (seen == null || product.createdAt.isAfter(seen)) {
          lastUsed[key] = product.createdAt;
          display[key] = product.name;
        }
      }

      final keys = lastUsed.keys.toList()
        ..sort((a, b) => lastUsed[b]!.compareTo(lastUsed[a]!));

      return [for (final key in keys) StapleName(name: display[key]!)];
    });
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
    return watchAllProductsForUser(userId).map((rows) {
      // Grouped in Dart rather than with GROUP BY ... COLLATE NOCASE, which
      // would list "Мляко" and "мляко" as two different habits.
      final uses = <String, int>{};
      final lastUsed = <String, DateTime>{};
      final display = <String, String>{};

      for (final product in rows) {
        final key = foldName(product.name);
        if (key.isEmpty) continue;

        uses[key] = (uses[key] ?? 0) + 1;
        final seen = lastUsed[key];
        if (seen == null || product.createdAt.isAfter(seen)) {
          lastUsed[key] = product.createdAt;
          // Show the most recent spelling, which is the one the user last
          // chose to type.
          display[key] = product.name;
        }
      }

      final keys = uses.keys.toList()
        ..sort((a, b) {
          final byUses = uses[b]!.compareTo(uses[a]!);
          if (byUses != 0) return byUses;
          return lastUsed[b]!.compareTo(lastUsed[a]!);
        });

      return [
        for (final key in keys.take(limit))
          ProductSuggestion(name: display[key]!, uses: uses[key]!),
      ];
    });
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
  /// The recipes linked to one meal, most recently linked first.
  Stream<List<Recipe>> watchRecipesForMeal(String mealId) {
    final query = select(recipes).join([
      innerJoin(mealRecipes, mealRecipes.recipeId.equalsExp(recipes.id)),
    ])
      ..where(mealRecipes.mealId.equals(mealId))
      ..orderBy([OrderingTerm.desc(mealRecipes.createdAt)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(recipes)).toList(),
    );
  }

  /// A user's whole library, newest first, with how many meals use each.
  Stream<List<LibraryRecipe>> watchLibrary(String userId) {
    final uses = mealRecipes.mealId.count();
    final query = select(recipes).join([
      leftOuterJoin(mealRecipes, mealRecipes.recipeId.equalsExp(recipes.id)),
    ])
      ..addColumns([uses])
      ..where(recipes.userId.equals(userId))
      ..groupBy([recipes.id])
      ..orderBy([OrderingTerm.desc(recipes.createdAt)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          LibraryRecipe(
            recipe: row.readTable(recipes),
            mealCount: row.read(uses) ?? 0,
          ),
      ],
    );
  }

  /// The user's existing copy of a link, so attaching the same video twice
  /// reuses one library entry instead of filling the library with duplicates.
  Future<Recipe?> recipeByUrl({
    required String userId,
    required String sourceUrl,
  }) {
    return (select(recipes)
          ..where(
            (t) => t.userId.equals(userId) & t.sourceUrl.equals(sourceUrl),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Recipe?> recipeById(String id) =>
      (select(recipes)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Stores what the importer read, and, when given, a better title than
  /// the one the recipe was saved with.
  Future<void> setRecipeDetails(String id, String details, {String? title}) {
    return (update(recipes)..where((r) => r.id.equals(id))).write(
      RecipesCompanion(
        details: Value(details),
        title: title == null ? const Value.absent() : Value(title),
      ),
    );
  }

  Future<void> insertRecipe(RecipesCompanion entry) =>
      into(recipes).insert(entry);

  Future<void> deleteRecipe(String id) =>
      (delete(recipes)..where((t) => t.id.equals(id))).go();

  Future<void> linkRecipe({
    required String mealId,
    required String recipeId,
  }) {
    return into(mealRecipes).insert(
      MealRecipesCompanion.insert(
        mealId: mealId,
        recipeId: recipeId,
        createdAt: DateTime.now(),
      ),
      // Linking twice is a no-op, not an error.
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> unlinkRecipe({
    required String mealId,
    required String recipeId,
  }) {
    return (delete(mealRecipes)..where(
      (t) => t.mealId.equals(mealId) & t.recipeId.equals(recipeId),
    )).go();
  }

  Future<List<MealRecipe>> linksForMeals(List<String> mealIds) {
    if (mealIds.isEmpty) return Future.value(const []);
    return (select(mealRecipes)..where((t) => t.mealId.isIn(mealIds))).get();
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
    List<MealRecipe> links = const [],
  }) {
    return transaction(() async {
      if (list != null) await into(shoppingLists).insert(list);
      for (final meal in meals) {
        await into(this.meals).insert(meal);
      }
      for (final product in products) {
        await into(this.products).insert(product);
      }
      // Recipes survive a meal or list delete, so only the links need putting
      // back — unless the recipe itself was deleted from the library in the
      // seconds before undo, in which case its link has nothing to point at.
      for (final link in links) {
        final stillThere = await (select(
          recipes,
        )..where((t) => t.id.equals(link.recipeId))).getSingleOrNull();
        if (stillThere == null) continue;
        await into(mealRecipes).insert(link, mode: InsertMode.insertOrIgnore);
      }
    });
  }
}

/// Case-insensitive key for a product name.
///
/// Folding happens in Dart, not SQL. SQLite's `NOCASE` collation and `lower()`
/// only fold ASCII A-Z, so "Халуми" and "халуми" compare as different strings
/// and "Мляко" appears twice in the suggestions. Every case-insensitive
/// comparison on names goes through this.
String foldName(String name) => name.trim().toLowerCase();

/// A name the user has typed before, with how often, for the composer's
/// suggestions.
class ProductSuggestion {
  final String name;
  final int uses;

  const ProductSuggestion({required this.name, required this.uses});
}

/// A library entry, with how many meals use it.
class LibraryRecipe {
  final Recipe recipe;
  final int mealCount;

  const LibraryRecipe({required this.recipe, required this.mealCount});
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
