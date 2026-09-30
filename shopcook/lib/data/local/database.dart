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

  /// When the meal was marked cooked, or null while it is still to come.
  /// A cooked meal leaves its list and the ideas pile but is kept, as the
  /// Plan screen's record of what was eaten.
  DateTimeColumn get cookedAt => dateTime().nullable()();

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

  /// When the item was cleared off its list after being bought, or null
  /// while it is still on it.
  ///
  /// Cleared rather than deleted because the rows are the user's history:
  /// suggestions count them, staples and hand-filed aisles are read from
  /// them. Deleting last week's milk would forget that milk is a staple.
  DateTimeColumn get clearedAt => dateTime().nullable()();

  /// In a shared list, the account that last changed this item, as the
  /// server recorded it; null for items only ever changed on this phone.
  /// Shown as "by Anna" when it is someone else.
  TextColumn get changedBy => text().nullable()();

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

/// What a scanned barcode turned out to be.
///
/// Filled from Open Food Facts, or from what the user typed when the code
/// was unknown there. A weekly shop scans the same products every week, so
/// the second scan is instant and works with no signal.
@DataClassName('ScannedProduct')
class BarcodeProducts extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}

/// A list shared with other people through the server.
///
/// Its presence is what makes the sync triggers queue changes to the list;
/// see [AppDatabase.createSyncTriggers].
@DataClassName('SharedListMark')
class SharedLists extends Table {
  TextColumn get listId =>
      text().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();

  /// Whether this user shared it (and so may stop sharing it for everyone)
  /// or joined it with a code.
  BoolColumn get isOwner => boolean().withDefault(const Constant(false))();

  /// The server's updated_at of the newest change pulled so far, as the
  /// server wrote it. Null until the first pull.
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {listId};
}

/// The people a shared list is shared with, by the name each chose.
@DataClassName('SharedMember')
class SharedMembers extends Table {
  TextColumn get listId =>
      text().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text()();

  /// Empty when they have not set one.
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {listId, userId};
}

/// Things the user has at home, so recipe imports and the week's shop can
/// leave them off.
@DataClassName('PantryItem')
class PantryItems extends Table {
  TextColumn get userId => text()();

  /// The folded name the item is matched by; see [foldName].
  TextColumn get key => text()();

  /// The name as the user last wrote it.
  TextColumn get name => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, key};
}

/// Changes to shared lists that have not reached the server yet.
///
/// Filled by triggers rather than by the repository, so no write path — and
/// there are many: adds, merges, ticks, undo restores, cascades — can forget
/// to queue its change. Only the row's identity is kept; the push reads the
/// row as it is then, so ten edits to one item send one update.
@DataClassName('OutboxEntry')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'list', 'meal' or 'product'.
  TextColumn get entity => text()();
  TextColumn get rowId => text()();
  TextColumn get listId => text()();
  BoolColumn get deleted => boolean()();
}

/// Switches the triggers read. While `applying` is 1 the sync is writing
/// what it pulled from the server, which must not be queued to go back up.
@DataClassName('SyncFlag')
class SyncFlags extends Table {
  TextColumn get name => text()();
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {name};
}

@DriftDatabase(
  tables: [
    ShoppingLists,
    Meals,
    Products,
    Recipes,
    MealRecipes,
    RecipeSearches,
    BarcodeProducts,
    SharedLists,
    SyncOutbox,
    SyncFlags,
    SharedMembers,
    PantryItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 12;

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
    onCreate: (m) async {
      await m.createAll();
      await createSyncTriggers();
      await createRecipeLinkTriggers();
    },
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
      // v7: names for scanned barcodes.
      if (from < 7) {
        await m.createTable(barcodeProducts);
      }
      // v8: bought items can be cleared off a list without being forgotten.
      if (from < 8) {
        await m.addColumn(products, products.clearedAt);
      }
      // v9: meals can be marked cooked.
      if (from < 9) {
        await m.addColumn(meals, meals.cookedAt);
      }
      // v10: lists can be shared, through a queue of changes to push.
      if (from < 10) {
        await m.createTable(sharedLists);
        await m.createTable(syncOutbox);
        await m.createTable(syncFlags);
        await createSyncTriggers();
      }
      // v11: who changed what in a shared list, and things at home.
      if (from < 11) {
        await m.addColumn(products, products.changedBy);
        await m.createTable(sharedMembers);
        await m.createTable(pantryItems);
      }
      // v12: recipes attached to a shared list's meals are shared too.
      if (from < 12) {
        await createRecipeLinkTriggers();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Queues every change to a shared list's name, meals and items.
  ///
  /// Written out as SQL, like the v5 rebuild, so the triggers a phone has
  /// are the ones of the day it upgraded. A change is queued only when its
  /// list is shared and the sync is not itself applying what it pulled.
  Future<void> createSyncTriggers() async {
    await customStatement(
      "INSERT OR IGNORE INTO sync_flags (name, value) VALUES ('applying', 0)",
    );

    const quiet =
        "(SELECT value FROM sync_flags WHERE name = 'applying') = 0";
    String shared(String row) =>
        'EXISTS (SELECT 1 FROM shared_lists WHERE list_id = $row.list_id)';
    String queue(String entity, String row, String listId, int deleted) =>
        'INSERT INTO sync_outbox (entity, row_id, list_id, deleted) '
        "VALUES ('$entity', $row.id, $listId, $deleted);";

    for (final (table, entity) in [('meals', 'meal'), ('products', 'product')]) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS sync_${table}_insert '
        'AFTER INSERT ON $table WHEN $quiet AND ${shared('NEW')} '
        'BEGIN ${queue(entity, 'NEW', 'NEW.list_id', 0)} END',
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS sync_${table}_update '
        'AFTER UPDATE ON $table WHEN $quiet AND ${shared('NEW')} '
        'BEGIN ${queue(entity, 'NEW', 'NEW.list_id', 0)} END',
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS sync_${table}_delete '
        'AFTER DELETE ON $table WHEN $quiet AND ${shared('OLD')} '
        'BEGIN ${queue(entity, 'OLD', 'OLD.list_id', 1)} END',
      );
    }
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS sync_lists_rename '
      'AFTER UPDATE OF name ON shopping_lists '
      'WHEN $quiet AND EXISTS '
      '(SELECT 1 FROM shared_lists WHERE list_id = NEW.id) '
      "BEGIN INSERT INTO sync_outbox (entity, row_id, list_id, deleted) "
      "VALUES ('list', NEW.id, NEW.id, 0); END",
    );
  }

  /// Queues changes to which recipes a shared list's meals use.
  ///
  /// A link is identified to the other members by meal and recipe address
  /// ("mealId|url"), because each keeps the recipe in their own library
  /// under their own id. The address is read while the recipe row still
  /// exists: every statement selects it from `recipes`, so a link whose
  /// recipe or meal has already gone queues nothing rather than a null.
  /// That is also why deleting a recipe has its own BEFORE trigger — by the
  /// time the cascade removes its links, the address is no longer there to
  /// read.
  Future<void> createRecipeLinkTriggers() async {
    const quiet =
        "(SELECT value FROM sync_flags WHERE name = 'applying') = 0";
    const shared =
        'EXISTS (SELECT 1 FROM shared_lists s WHERE s.list_id = m.list_id)';
    String queue(String mealId, String recipeId, int deleted) =>
        'INSERT INTO sync_outbox (entity, row_id, list_id, deleted) '
        "SELECT 'link', $mealId || '|' || r.source_url, m.list_id, $deleted "
        'FROM meals m, recipes r '
        'WHERE m.id = $mealId AND r.id = $recipeId AND $shared;';

    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS sync_links_insert '
      'AFTER INSERT ON meal_recipes WHEN $quiet '
      'BEGIN ${queue('NEW.meal_id', 'NEW.recipe_id', 0)} END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS sync_links_delete '
      'AFTER DELETE ON meal_recipes WHEN $quiet '
      'BEGIN ${queue('OLD.meal_id', 'OLD.recipe_id', 1)} END',
    );
    // A recipe leaving the library takes its links with it.
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS sync_links_recipe_delete '
      'BEFORE DELETE ON recipes WHEN $quiet '
      'BEGIN '
      'INSERT INTO sync_outbox (entity, row_id, list_id, deleted) '
      "SELECT 'link', mr.meal_id || '|' || OLD.source_url, m.list_id, 1 "
      'FROM meal_recipes mr JOIN meals m ON m.id = mr.meal_id '
      'WHERE mr.recipe_id = OLD.id AND $shared; '
      'END',
    );
    // The title and picture are often filled in a moment after saving.
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS sync_links_recipe_update '
      'AFTER UPDATE OF title, thumbnail_url ON recipes WHEN $quiet '
      'BEGIN '
      'INSERT INTO sync_outbox (entity, row_id, list_id, deleted) '
      "SELECT 'link', mr.meal_id || '|' || NEW.source_url, m.list_id, 0 "
      'FROM meal_recipes mr JOIN meals m ON m.id = mr.meal_id '
      'WHERE mr.recipe_id = NEW.id AND $shared; '
      'END',
    );
  }

  /// The recipe at [url] that [mealId] uses, if it uses one.
  Future<Recipe?> linkedRecipe({
    required String mealId,
    required String url,
  }) async {
    final query = select(recipes).join([
      innerJoin(mealRecipes, mealRecipes.recipeId.equalsExp(recipes.id)),
    ])..where(mealRecipes.mealId.equals(mealId) & recipes.sourceUrl.equals(url));
    final rows = await query.get();
    return rows.isEmpty ? null : rows.first.readTable(recipes);
  }

  /// Every recipe used by a meal of [listId], with the meal it is on.
  Future<List<({String mealId, Recipe recipe})>> linkedRecipesForList(
    String listId,
  ) async {
    final query = select(recipes).join([
      innerJoin(mealRecipes, mealRecipes.recipeId.equalsExp(recipes.id)),
      innerJoin(meals, meals.id.equalsExp(mealRecipes.mealId)),
    ])..where(meals.listId.equals(listId));
    return [
      for (final row in await query.get())
        (
          mealId: row.readTable(mealRecipes).mealId,
          recipe: row.readTable(recipes),
        ),
    ];
  }

  /// Runs [writes] as the sync applying pulled changes: nothing written in
  /// it is queued to be pushed back.
  Future<T> applyingRemote<T>(Future<T> Function() writes) => transaction(
    () async {
      await customStatement(
        "UPDATE sync_flags SET value = 1 WHERE name = 'applying'",
      );
      try {
        return await writes();
      } finally {
        await customStatement(
          "UPDATE sync_flags SET value = 0 WHERE name = 'applying'",
        );
      }
    },
  );

  // Sharing
  Stream<List<SharedListMark>> watchSharedLists() =>
      select(sharedLists).watch();

  Future<SharedListMark?> sharedList(String listId) =>
      (select(sharedLists)..where((t) => t.listId.equals(listId)))
          .getSingleOrNull();

  /// The shared lists belonging to [userId] on this phone.
  Future<List<SharedListMark>> sharedListsFor(String userId) async {
    final query = select(sharedLists).join([
      innerJoin(shoppingLists, shoppingLists.id.equalsExp(sharedLists.listId)),
    ])..where(shoppingLists.userId.equals(userId));
    return [for (final row in await query.get()) row.readTable(sharedLists)];
  }

  Future<void> markShared(String listId, {required bool isOwner}) =>
      into(sharedLists).insertOnConflictUpdate(
        SharedListsCompanion.insert(listId: listId, isOwner: Value(isOwner)),
      );

  /// Replaces who a shared list's members are, as last pulled.
  Future<void> replaceMembers(
    String listId,
    List<({String userId, String name})> members,
  ) => transaction(() async {
    await (delete(sharedMembers)..where((t) => t.listId.equals(listId))).go();
    for (final member in members) {
      await into(sharedMembers).insert(
        SharedMembersCompanion.insert(
          listId: listId,
          userId: member.userId,
          name: member.name,
        ),
      );
    }
  });

  /// Member names of a shared list, by account id.
  Stream<Map<String, String>> watchMemberNames(String listId) =>
      (select(sharedMembers)..where((t) => t.listId.equals(listId)))
          .watch()
          .map((rows) => {for (final row in rows) row.userId: row.name});

  // Pantry
  Stream<List<PantryItem>> watchPantry(String userId) =>
      (select(pantryItems)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<void> addToPantry(String userId, String name) =>
      into(pantryItems).insertOnConflictUpdate(
        PantryItemsCompanion.insert(
          userId: userId,
          key: foldName(name),
          name: name.trim(),
          addedAt: DateTime.now(),
        ),
      );

  Future<void> removeFromPantry(String userId, String key) =>
      (delete(pantryItems)
            ..where((t) => t.userId.equals(userId) & t.key.equals(key)))
          .go();

  Future<void> setSharedCursor(String listId, String cursor) =>
      (update(sharedLists)..where((t) => t.listId.equals(listId))).write(
        SharedListsCompanion(cursor: Value(cursor)),
      );

  /// Queues everything on a list to be pushed: its meals, its items and
  /// the recipes on its meals. Used when a list is first shared, so its
  /// contents go up by the same retrying path as any later change, rather
  /// than in one upload that a dropped connection could leave half done.
  Future<void> queueWholeList(String listId) => transaction(() async {
    Future<void> queue(String entity, String rowId) => into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        entity: entity,
        rowId: rowId,
        listId: listId,
        deleted: false,
      ),
    );

    for (final meal in await allMealsForList(listId)) {
      await queue('meal', meal.id);
    }
    for (final product in await productsForList(listId)) {
      await queue('product', product.id);
    }
    for (final link in await linkedRecipesForList(listId)) {
      await queue('link', '${link.mealId}|${link.recipe.sourceUrl}');
    }
  });

  /// Stops treating a list as shared, and drops what it had queued. The
  /// list itself stays, as an ordinary list on this phone.
  Future<void> forgetShared(String listId) => transaction(() async {
    await (delete(syncOutbox)..where((t) => t.listId.equals(listId))).go();
    await (delete(sharedLists)..where((t) => t.listId.equals(listId))).go();
  });

  /// Queued changes to [userId]'s lists, oldest first.
  Future<List<OutboxEntry>> pendingOutbox(String userId) async {
    final query = select(syncOutbox).join([
      innerJoin(shoppingLists, shoppingLists.id.equalsExp(syncOutbox.listId)),
    ])
      ..where(shoppingLists.userId.equals(userId))
      ..orderBy([OrderingTerm.asc(syncOutbox.id)]);
    return [for (final row in await query.get()) row.readTable(syncOutbox)];
  }

  Stream<int> watchOutboxSize() => syncOutbox.count().watchSingle();

  Future<void> dropOutbox(Iterable<int> ids) =>
      (delete(syncOutbox)..where((t) => t.id.isIn(ids))).go();

  /// Ids with a change still waiting to go up. A pulled row must not
  /// overwrite one of these, or the local edit would be lost.
  Future<Set<String>> pendingRowIds(String listId) async {
    final rows = await (select(syncOutbox)
          ..where((t) => t.listId.equals(listId)))
        .get();
    return {for (final row in rows) row.rowId};
  }

  Future<List<Meal>> allMealsForList(String listId) =>
      (select(meals)..where((t) => t.listId.equals(listId))).get();

  Future<void> upsertMeal(Meal meal) =>
      into(meals).insertOnConflictUpdate(meal);

  Future<void> upsertProduct(Product product) =>
      into(products).insertOnConflictUpdate(product);

  Future<void> upsertList(ShoppingListsCompanion list) =>
      into(shoppingLists).insertOnConflictUpdate(list);

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

  /// Everything this phone holds for [userId], for account deletion. Lists
  /// take their meals, products and recipe links with them by cascade;
  /// recipes are owned directly. Shared caches (searches, barcode names)
  /// hold nothing personal and stay.
  Future<void> deleteUserData(String userId) => transaction(() async {
    for (final mark in await sharedListsFor(userId)) {
      await forgetShared(mark.listId);
    }
    await (delete(shoppingLists)..where((t) => t.userId.equals(userId))).go();
    await (delete(pantryItems)..where((t) => t.userId.equals(userId))).go();
    await (delete(recipes)..where((t) => t.userId.equals(userId))).go();
  });

  Future<void> insertList(ShoppingListsCompanion entry) =>
      into(shoppingLists).insert(entry);

  /// Deletes a list from this phone. A shared list is forgotten first, so
  /// the cascade through its meals and items is not queued as deletions for
  /// every other member.
  Future<void> deleteList(String id) => transaction(() async {
    await forgetShared(id);
    await (delete(shoppingLists)..where((t) => t.id.equals(id))).go();
  });

  Future<void> renameList(String id, String name) =>
      (update(shoppingLists)..where((t) => t.id.equals(id))).write(
        ShoppingListsCompanion(name: Value(name)),
      );

  /// Copies a list, its meals, their recipe links and every item still on
  /// it into a new list, as one transaction.
  ///
  /// The copy is a fresh start: nothing ticked, no meal pinned to last
  /// week's day, and items already cleared off the original left behind.
  /// Prices, aisles and staples come along — they describe the item, not
  /// the shop. [newId] makes up an id for each copied row.
  Future<void> copyList({
    required String fromId,
    required String toId,
    required String name,
    required String userId,
    required String Function() newId,
  }) => transaction(() async {
    final now = DateTime.now();
    await into(shoppingLists).insert(
      ShoppingListsCompanion.insert(
        id: toId,
        name: name,
        userId: Value(userId),
        createdAt: now,
      ),
    );

    final mealIds = <String, String>{};
    for (final meal in await mealsForList(fromId)) {
      if (meal.cookedAt != null) continue; // already eaten; not next week's
      final id = newId();
      mealIds[meal.id] = id;
      await into(meals).insert(
        meal.copyWith(id: id, listId: toId, plannedFor: const Value(null)),
      );
    }

    for (final link in await linksForMeals(mealIds.keys.toList())) {
      await into(mealRecipes).insert(
        link.copyWith(mealId: mealIds[link.mealId]!, createdAt: now),
      );
    }

    final kept = (await productsForList(fromId))
        .where((p) => p.clearedAt == null)
        .toList();
    for (final product in kept) {
      await into(products).insert(
        product.copyWith(
          id: newId(),
          listId: toId,
          mealId: Value(
            product.mealId == null ? null : mealIds[product.mealId],
          ),
          isChecked: false,
          changedBy: const Value(null),
          createdAt: now,
        ),
      );
    }
  });

  Stream<ShoppingList?> watchList(String id) =>
      (select(shoppingLists)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  /// One-shot read, for snapshotting a list before it is deleted.
  Future<ShoppingList?> listById(String id) =>
      (select(shoppingLists)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  // Meals
  /// The meals still to cook on a list.
  Stream<List<Meal>> watchMealsForList(String listId) =>
      (select(meals)
        ..where((t) => t.listId.equals(listId) & t.cookedAt.isNull())
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
      ..where(shoppingLists.userId.equals(userId) & meals.cookedAt.isNull())
      ..orderBy([OrderingTerm.desc(meals.createdAt)]);

    return [
      for (final row in await query.get())
        (
          meal: row.readTable(meals),
          listName: row.readTable(shoppingLists).name,
        ),
    ];
  }

  /// Meals of [userId] joined to their list, which is where ownership
  /// lives. The plan queries read across lists, so without the join a phone
  /// shared by two accounts would show each the other's week.
  JoinedSelectStatement<HasResultSet, dynamic> _userMeals(String userId) =>
      select(meals).join([
        innerJoin(shoppingLists, shoppingLists.id.equalsExp(meals.listId)),
      ])..where(shoppingLists.userId.equals(userId));

  Stream<List<Meal>> _watchMeals(
    JoinedSelectStatement<HasResultSet, dynamic> query,
  ) => query.watch().map(
    (rows) => [for (final row in rows) row.readTable(meals)],
  );

  /// Every planned meal in a half-open date range, across all lists — the
  /// week view is not scoped to one shopping list, because a week is not.
  /// Cooked meals stay, so the day shows what was eaten.
  Stream<List<Meal>> watchMealsPlannedBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) => _watchMeals(
    _userMeals(userId)
      ..where(
        meals.plannedFor.isBiggerOrEqualValue(from) &
            meals.plannedFor.isSmallerThanValue(to),
      )
      ..orderBy([
        OrderingTerm.asc(meals.plannedFor),
        OrderingTerm.asc(meals.createdAt),
      ]),
  );

  /// Meals that are still just ideas, newest first.
  Stream<List<Meal>> watchUnplannedMeals(String userId) => _watchMeals(
    _userMeals(userId)
      ..where(meals.plannedFor.isNull() & meals.cookedAt.isNull())
      ..orderBy([OrderingTerm.desc(meals.createdAt)]),
  );

  /// The most recently cooked meals, newest first.
  Stream<List<Meal>> watchCookedMeals(String userId, {int limit = 10}) =>
      _watchMeals(
        _userMeals(userId)
          ..where(meals.cookedAt.isNotNull())
          ..orderBy([OrderingTerm.desc(meals.cookedAt)])
          ..limit(limit),
      );

  /// Marks a meal cooked at [at], or back to still-to-cook when null.
  Future<void> setMealCooked(String id, DateTime? at) =>
      (update(meals)..where((t) => t.id.equals(id))).write(
        MealsCompanion(cookedAt: Value(at)),
      );

  /// A cooked meal's ingredients that are still showing, to clear with it.
  Future<List<Product>> visibleProductsForMeal(String mealId) =>
      (select(products)
            ..where((t) => t.mealId.equals(mealId) & t.clearedAt.isNull()))
          .get();

  Future<void> setMealPlannedFor(String id, DateTime? day) =>
      (update(meals)..where((t) => t.id.equals(id))).write(
        MealsCompanion(plannedFor: Value(day)),
      );

  // Products
  //
  // The watch* queries below are what the screens show, so they leave out
  // cleared rows. The cross-list history queries (suggestions, staples,
  // remembered aisles) and the undo snapshots deliberately do not.
  Stream<List<Product>> watchProductsForList(String listId) =>
      (select(products)
        ..where((t) => t.listId.equals(listId) & t.clearedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Stream<List<Product>> watchProductsForMeal(String mealId) =>
      (select(products)
        ..where((t) => t.mealId.equals(mealId) & t.clearedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Stream<List<Product>> watchUnassignedProducts(String listId) =>
      (select(products)
        ..where(
          (t) =>
              t.listId.equals(listId) &
              t.mealId.isNull() &
              t.clearedAt.isNull(),
        )
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
          t.isChecked.equals(false) &
          t.clearedAt.isNull(),
    )).get();

    final needle = foldName(name);
    for (final candidate in candidates) {
      if (foldName(candidate.name) == needle) return candidate;
    }
    return null;
  }

  /// Ticked items on the list itself (not in a meal) that are still showing.
  Future<List<Product>> checkedLooseProducts(String listId) =>
      (select(products)..where(
            (t) =>
                t.listId.equals(listId) &
                t.mealId.isNull() &
                t.isChecked.equals(true) &
                t.clearedAt.isNull(),
          ))
          .get();

  /// Clears the given rows off their list at [at], or puts them back when
  /// [at] is null.
  Future<void> setProductsCleared(List<String> ids, DateTime? at) =>
      (update(products)..where((t) => t.id.isIn(ids))).write(
        ProductsCompanion(clearedAt: Value(at)),
      );

  /// Rewrites what an item is. The aisle is passed in whole because a new
  /// name can mean a different hand-filed aisle, or none.
  Future<void> editProduct(
    String id, {
    required String name,
    required String quantity,
    required String unit,
    required String? categoryOverride,
  }) =>
      (update(products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(
          name: Value(name),
          quantity: Value(quantity),
          unit: Value(unit),
          categoryOverride: Value(categoryOverride),
        ),
      );

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
  Future<void> setRecipeDetails(
    String id,
    String details, {
    String? title,
    String? thumbnailUrl,
  }) {
    return (update(recipes)..where((r) => r.id.equals(id))).write(
      RecipesCompanion(
        details: Value(details),
        title: title == null ? const Value.absent() : Value(title),
        thumbnailUrl: thumbnailUrl == null
            ? const Value.absent()
            : Value(thumbnailUrl),
      ),
    );
  }

  Future<void> setRecipeThumbnail(String id, String thumbnailUrl) =>
      (update(recipes)..where((r) => r.id.equals(id))).write(
        RecipesCompanion(thumbnailUrl: Value(thumbnailUrl)),
      );

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

  // BarcodeProducts
  Future<ScannedProduct?> scannedProduct(String code) =>
      (select(barcodeProducts)..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  Future<void> rememberBarcode(String code, String name) =>
      into(barcodeProducts).insertOnConflictUpdate(
        BarcodeProductsCompanion.insert(
          code: code,
          name: name,
          updatedAt: DateTime.now(),
        ),
      );

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
