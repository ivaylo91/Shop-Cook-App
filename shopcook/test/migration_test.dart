import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// The v1 schema, exactly as Drift created it before `plannedFor` existed.
///
/// Written out by hand rather than generated so this test keeps describing
/// what is actually installed on a phone that has not upgraded yet. Every
/// later step in the ladder gets its own starting point here.
const _v1Schema = [
  'CREATE TABLE shopping_lists ('
      'id TEXT NOT NULL, '
      'name TEXT NOT NULL, '
      'created_at INTEGER NOT NULL, '
      'PRIMARY KEY (id))',
  'CREATE TABLE meals ('
      'id TEXT NOT NULL, '
      'list_id TEXT NOT NULL REFERENCES shopping_lists (id) ON DELETE CASCADE, '
      'name TEXT NOT NULL, '
      'created_at INTEGER NOT NULL, '
      'PRIMARY KEY (id))',
  'CREATE TABLE products ('
      'id TEXT NOT NULL, '
      'list_id TEXT NOT NULL REFERENCES shopping_lists (id) ON DELETE CASCADE, '
      'meal_id TEXT NULL REFERENCES meals (id) ON DELETE CASCADE, '
      'name TEXT NOT NULL, '
      "quantity TEXT NOT NULL DEFAULT '', "
      "unit TEXT NOT NULL DEFAULT '', "
      'is_checked INTEGER NOT NULL DEFAULT 0 CHECK (is_checked IN (0, 1)), '
      'created_at INTEGER NOT NULL, '
      'PRIMARY KEY (id))',
  'CREATE TABLE recipes ('
      'id TEXT NOT NULL, '
      'meal_id TEXT NOT NULL REFERENCES meals (id) ON DELETE CASCADE, '
      'title TEXT NOT NULL, '
      'source_url TEXT NOT NULL, '
      "thumbnail_url TEXT NOT NULL DEFAULT '', "
      "source_type TEXT NOT NULL DEFAULT 'web', "
      'created_at INTEGER NOT NULL, '
      'PRIMARY KEY (id))',
];

void main() {
  /// Builds a database shaped like the given schema version, with one list,
  /// one meal, one product and one recipe already in it.
  Database seedV1() {
    final raw = sqlite3.openInMemory();
    for (final statement in _v1Schema) {
      raw.execute(statement);
    }

    const epoch = 1700000000;
    raw.execute(
      'INSERT INTO shopping_lists (id, name, created_at) VALUES (?, ?, ?)',
      ['list-1', 'Weekly groceries', epoch],
    );
    raw.execute(
      'INSERT INTO meals (id, list_id, name, created_at) VALUES (?, ?, ?, ?)',
      ['meal-1', 'list-1', 'Bolognese', epoch],
    );
    raw.execute(
      'INSERT INTO products (id, list_id, meal_id, name, quantity, unit, '
      'is_checked, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      ['prod-1', 'list-1', 'meal-1', 'Beef mince', '500', 'g', 0, epoch],
    );
    raw.execute(
      'INSERT INTO recipes (id, meal_id, title, source_url, thumbnail_url, '
      'source_type, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        'recipe-1',
        'meal-1',
        'Best bolognese',
        'https://example.com/r',
        '',
        'web',
        epoch,
      ],
    );

    raw.execute('PRAGMA user_version = 1');
    return raw;
  }

  test('a v1 database upgrades to the current schema', () async {
    final raw = seedV1();
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening runs the ladder; the first query is what forces it. A v1 list
    // has no owner, so it is only visible once claimed.
    final claimed = await db.claimUnownedLists('user-1');
    final lists = await db.watchLists('user-1').first;

    expect(claimed, 1);
    expect(lists.single.name, 'Weekly groceries');
    expect(raw.userVersion, db.schemaVersion);
  });

  test('upgrading keeps every row, and the new column reads as null', () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(seedV1()));
    addTearDown(db.close);

    final meals = await db.watchMealsForList('list-1').first;
    final products = await db.watchProductsForList('list-1').first;
    final recipes = await db.watchRecipesForMeal('meal-1').first;

    expect(meals.single.name, 'Bolognese');
    expect(
      meals.single.plannedFor,
      isNull,
      reason: 'an existing meal has no planned day until one is set',
    );
    expect(products.single.name, 'Beef mince');
    expect(products.single.quantity, '500');
    expect(recipes.single.title, 'Best bolognese');
  });

  test('the upgraded column is writable and queryable', () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(seedV1()));
    addTearDown(db.close);

    final day = DateTime(2026, 9, 14);
    await db.setMealPlannedFor('meal-1', day);

    final planned = await db
        .watchMealsPlannedBetween(day, day.add(const Duration(days: 1)))
        .first;

    expect(planned.single.id, 'meal-1');
    expect(await db.watchUnplannedMeals().first, isEmpty);
  });

  test('foreign keys still cascade after an upgrade', () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(seedV1()));
    addTearDown(db.close);

    // beforeOpen turns the pragma on; without it the cascade is a silent
    // no-op and the ingredient would outlive its list.
    await db.deleteList('list-1');

    expect(await db.watchProductsForList('list-1').first, isEmpty);
    expect(await db.watchMealsForList('list-1').first, isEmpty);
  });

  test('a v1 list arrives unowned, not owned by nobody-in-particular',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(seedV1()));
    addTearDown(db.close);

    // The migration cannot know who the user is, so it must not guess.
    expect(await db.watchLists('user-1').first, isEmpty);
    expect(await db.watchLists('user-2').first, isEmpty);

    await db.claimUnownedLists('user-1');

    expect((await db.watchLists('user-1').first).single.id, 'list-1');
    expect(await db.watchLists('user-2').first, isEmpty);
  });

  test('an upgraded v1 database has exactly the schema of a fresh one',
      () async {
    // The strongest check the ladder can get: Drift builds a fresh database
    // from the current table definitions and compares it with the upgraded
    // one, table by table and column by column. It catches a step that adds
    // a column with the wrong default, forgets an index, or — for v5 — a
    // hand-written table rebuild that drifts from the Dart definition.
    final db = AppDatabase.forTesting(NativeDatabase.opened(seedV1()));
    addTearDown(db.close);

    await db.watchLists('user-1').first; // force the upgrade
    await db.validateDatabaseSchema();
  });

  test('v5 turns each attached recipe into a library entry and a link',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(seedV1()));
    addTearDown(db.close);

    // Still reachable from its meal, now through the join table.
    final onMeal = await db.watchRecipesForMeal('meal-1').first;
    expect(onMeal.single.title, 'Best bolognese');
    expect(
      onMeal.single.userId,
      isNull,
      reason: 'its list was unowned, so it is too, until someone signs in',
    );

    await db.claimUnownedLists('user-1');

    final library = await db.watchLibrary('user-1').first;
    expect(library.single.recipe.id, 'recipe-1');
    expect(library.single.mealCount, 1);
  });

  test('after v5, deleting a list keeps its recipes in the library', () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(seedV1()));
    addTearDown(db.close);
    await db.claimUnownedLists('user-1');

    // This is the bug v5 exists to fix: the recipe used to cascade away.
    await db.deleteList('list-1');

    final library = await db.watchLibrary('user-1').first;
    expect(library.single.recipe.title, 'Best bolognese');
    expect(library.single.mealCount, 0, reason: 'its meal is gone, it is not');
  });

  test('a fresh database is created at the current version', () async {
    final raw = sqlite3.openInMemory();
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.insertList(
      ShoppingListsCompanion.insert(
        id: 'l',
        name: 'New',
        userId: const Value('user-1'),
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await db.insertMeal(
      MealsCompanion.insert(
        id: 'm',
        listId: 'l',
        name: 'Soup',
        createdAt: DateTime(2026, 1, 1),
        plannedFor: Value(DateTime(2026, 1, 2)),
      ),
    );

    expect(raw.userVersion, db.schemaVersion);
    expect(
      (await db.watchMealsForList('l').first).single.plannedFor,
      DateTime(2026, 1, 2),
    );
  });
}
