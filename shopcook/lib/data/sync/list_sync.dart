import 'package:drift/drift.dart' show Value;

import '../local/database.dart';
import '../remote/shared_list_remote.dart';

/// Keeps shared lists in step between this phone and the server.
///
/// The phone's database stays the source for every screen. Changes to a
/// shared list are queued by triggers as they happen (see
/// [AppDatabase.createSyncTriggers]); [sync] pushes the queue, then pulls
/// what other members changed since the last pull. Conflicts are settled by
/// whichever write reached the server last, which for a shopping list —
/// two people ticking the same milk — is the right answer.
class ListSync {
  final AppDatabase _db;
  final SharedListRemote _remote;

  ListSync(this._db, this._remote);

  static const mealsTable = 'shared_meals';
  static const productsTable = 'shared_products';

  /// How far before the last pulled change the next pull starts. Rows are
  /// stamped when their transaction starts, so one that commits late can
  /// carry a time just before the newest already seen; re-reading a few
  /// seconds is harmless, because applying a row twice changes nothing.
  static const _overlap = Duration(seconds: 5);

  bool _running = false;
  bool _again = false;

  /// Shares [list] and returns an invite code for it. Sharing a list that
  /// is already shared only fetches a code.
  Future<String> share(ShoppingList list) async {
    if (await _db.sharedList(list.id) == null) {
      await _remote.createList(id: list.id, name: list.name);
      // Marked before the snapshot is read, so an edit made while it
      // uploads is queued rather than missed.
      await _db.markShared(list.id, isOwner: true);
      await _remote.upsert(mealsTable, [
        for (final meal in await _db.allMealsForList(list.id)) mealRow(meal),
      ]);
      await _remote.upsert(productsTable, [
        for (final product in await _db.productsForList(list.id))
          productRow(product),
      ]);
    }
    return _remote.createInvite(list.id);
  }

  /// Joins the list behind [code] and brings it onto this phone. Returns
  /// its id, or null when the code does not work.
  Future<String?> join(String code, {required String userId}) async {
    final listId = await _remote.join(code);
    if (listId == null) return null;

    if (await _db.listById(listId) == null) {
      final name = await _remote.listName(listId) ?? '';
      await _db.upsertList(
        ShoppingListsCompanion.insert(
          id: listId,
          name: name,
          userId: Value(userId),
          createdAt: DateTime.now(),
        ),
      );
    }
    if (await _db.sharedList(listId) == null) {
      await _db.markShared(listId, isOwner: false);
    }

    final mark = await _db.sharedList(listId);
    if (mark != null) await _pull(mark);
    return listId;
  }

  /// Stops sharing: the owner takes the list off the server for everyone,
  /// anyone else leaves it. Either way this phone keeps its copy.
  Future<void> stopSharing(String listId, {required String userId}) async {
    final mark = await _db.sharedList(listId);
    if (mark == null) return;
    if (mark.isOwner) {
      await _remote.deleteShared(listId);
    } else {
      await _remote.leave(listId, userId);
    }
    await _db.forgetShared(listId);
  }

  /// Fires when another member changes something in a shared list.
  Stream<void> remoteChanges() => _remote.changes();

  /// Pushes what is queued and pulls what changed, for [userId]'s shared
  /// lists. Calls that arrive while one is running fold into one more pass
  /// rather than running side by side.
  Future<void> sync(String userId) async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _push(userId);
        for (final mark in await _db.sharedListsFor(userId)) {
          await _pull(mark);
        }
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _push(String userId) async {
    final pending = await _db.pendingOutbox(userId);
    if (pending.isEmpty) return;

    // Only the latest entry per row matters: the row is read as it is now.
    final latest = <(String, String), OutboxEntry>{};
    for (final entry in pending) {
      latest[(entry.entity, entry.rowId)] = entry;
    }

    final renamed = <String>[];
    final meals = <Map<String, dynamic>>[];
    final products = <Map<String, dynamic>>[];
    final goneMeals = <String>[];
    final goneProducts = <String>[];

    for (final entry in latest.values) {
      switch (entry.entity) {
        case 'list':
          renamed.add(entry.rowId);
        case 'meal':
          final meal = entry.deleted ? null : await _db.mealById(entry.rowId);
          meal == null ? goneMeals.add(entry.rowId) : meals.add(mealRow(meal));
        case 'product':
          final product = entry.deleted
              ? null
              : await _db.productById(entry.rowId);
          product == null
              ? goneProducts.add(entry.rowId)
              : products.add(productRow(product));
      }
    }

    for (final listId in renamed) {
      final list = await _db.listById(listId);
      if (list != null) await _remote.renameList(listId, list.name);
    }
    // Meals before products, so a new item's meal is there when it lands.
    await _remote.upsert(mealsTable, meals);
    await _remote.upsert(productsTable, products);
    await _remote.tombstone(productsTable, goneProducts);
    await _remote.tombstone(mealsTable, goneMeals);

    // Only what was read: anything queued during the push goes next time.
    await _db.dropOutbox([for (final entry in pending) entry.id]);
  }

  Future<void> _pull(SharedListMark mark) async {
    final name = await _remote.listName(mark.listId);
    if (name == null) {
      // Unshared by its owner, or this user was removed. Keep the copy.
      await _db.forgetShared(mark.listId);
      return;
    }

    final since = mark.cursor == null
        ? null
        : DateTime.parse(
            mark.cursor!,
          ).subtract(_overlap).toUtc().toIso8601String();
    final meals = await _remote.changesSince(mealsTable, mark.listId, since);
    final products = await _remote.changesSince(
      productsTable,
      mark.listId,
      since,
    );

    // A row edited here and not yet pushed keeps the local edit: pulling
    // the server's older copy over it would lose it.
    final pending = await _db.pendingRowIds(mark.listId);
    var newest = mark.cursor;

    await _db.applyingRemote(() async {
      final list = await _db.listById(mark.listId);
      if (list != null && list.name != name && !pending.contains(list.id)) {
        await _db.renameList(list.id, name);
      }

      for (final row in meals) {
        newest = _later(newest, row['updated_at'] as String);
        final id = row['id'] as String;
        if (pending.contains(id)) continue;
        if (row['deleted_at'] != null) {
          await _db.deleteMeal(id);
        } else {
          await _db.upsertMeal(mealFrom(row));
        }
      }

      for (final row in products) {
        newest = _later(newest, row['updated_at'] as String);
        final id = row['id'] as String;
        if (pending.contains(id)) continue;
        if (row['deleted_at'] != null) {
          await _db.deleteProduct(id);
          continue;
        }
        var product = productFrom(row);
        // Its meal was deleted, or has not arrived: keep the item loose
        // rather than fail on the foreign key.
        if (product.mealId != null &&
            await _db.mealById(product.mealId!) == null) {
          product = product.copyWith(mealId: const Value(null));
        }
        await _db.upsertProduct(product);
      }
    });

    if (newest != null && newest != mark.cursor) {
      await _db.setSharedCursor(mark.listId, newest!);
    }
  }

  static String? _later(String? a, String b) {
    if (a == null) return b;
    return DateTime.parse(b).isAfter(DateTime.parse(a)) ? b : a;
  }

  // Row mapping. Instants go up in UTC and come back to local time; a
  // planned day is a calendar date, which must not shift with time zones.

  static String _instant(DateTime value) => value.toUtc().toIso8601String();

  static DateTime _local(Object value) =>
      DateTime.parse(value as String).toLocal();

  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> mealRow(Meal meal) => {
    'id': meal.id,
    'list_id': meal.listId,
    'name': meal.name,
    'planned_for': meal.plannedFor == null ? null : _date(meal.plannedFor!),
    'cooked_at': meal.cookedAt == null ? null : _instant(meal.cookedAt!),
    'created_at': _instant(meal.createdAt),
    'deleted_at': null,
  };

  static Meal mealFrom(Map<String, dynamic> row) {
    final planned = row['planned_for'] as String?;
    final day = planned == null ? null : DateTime.parse(planned);
    return Meal(
      id: row['id'] as String,
      listId: row['list_id'] as String,
      name: row['name'] as String,
      plannedFor: day == null ? null : DateTime(day.year, day.month, day.day),
      cookedAt: row['cooked_at'] == null ? null : _local(row['cooked_at']),
      createdAt: _local(row['created_at']),
    );
  }

  static Map<String, dynamic> productRow(Product product) => {
    'id': product.id,
    'list_id': product.listId,
    'meal_id': product.mealId,
    'name': product.name,
    'quantity': product.quantity,
    'unit': product.unit,
    'is_checked': product.isChecked,
    'price': product.price,
    'category_override': product.categoryOverride,
    'is_staple': product.isStaple,
    'cleared_at': product.clearedAt == null
        ? null
        : _instant(product.clearedAt!),
    'created_at': _instant(product.createdAt),
    'deleted_at': null,
  };

  static Product productFrom(Map<String, dynamic> row) => Product(
    id: row['id'] as String,
    listId: row['list_id'] as String,
    mealId: row['meal_id'] as String?,
    name: row['name'] as String,
    quantity: row['quantity'] as String? ?? '',
    unit: row['unit'] as String? ?? '',
    isChecked: row['is_checked'] as bool? ?? false,
    price: (row['price'] as num?)?.toDouble(),
    categoryOverride: row['category_override'] as String?,
    isStaple: row['is_staple'] as bool? ?? false,
    clearedAt: row['cleared_at'] == null ? null : _local(row['cleared_at']),
    createdAt: _local(row['created_at']),
  );
}
