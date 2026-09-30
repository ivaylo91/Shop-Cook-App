import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

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
  static const linksTable = 'shared_meal_recipes';

  static const _uuid = Uuid();

  /// How far before the last pulled change the next pull starts. Rows are
  /// stamped when their transaction starts, so one that commits late can
  /// carry a time just before the newest already seen; re-reading a few
  /// seconds is harmless, because applying a row twice changes nothing.
  static const _overlap = Duration(seconds: 5);

  bool _running = false;
  bool _again = false;

  /// The name this user shows under to the people they share lists with.
  /// Set from the settings; pushed on the next sync when it changes.
  String displayName = '';
  String? _pushedName;

  final _news = StreamController<SyncNews>.broadcast();

  /// Changes other members made, as they arrive — for a quiet "Anna ticked
  /// 3 items" rather than items silently changing under the user's thumb.
  Stream<SyncNews> get news => _news.stream;

  /// Shares [list] and returns an invite code for it. Sharing a list that
  /// is already shared only fetches a code.
  Future<String> share(ShoppingList list) async {
    if (await _db.sharedList(list.id) == null) {
      // Safe to repeat: a list already on the server from an attempt that
      // got no further is simply left as it is.
      await _remote.createList(id: list.id, name: list.name);
      // Its contents are queued, not uploaded here. If the connection drops
      // now, the list is still marked and its contents still waiting, and
      // the next sync sends them; an upload done in place would have been
      // lost for good.
      await _db.markShared(list.id, isOwner: true);
      await _db.queueWholeList(list.id);
    }
    final userId = list.userId;
    if (userId != null) await _push(userId);
    await _pushName(list.userId, force: true);
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
    await _pushName(userId, force: true);

    final mark = await _db.sharedList(listId);
    if (mark != null) await _pull(mark, userId);
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
        final marks = await _db.sharedListsFor(userId);
        if (marks.isNotEmpty) await _pushName(userId);
        for (final mark in marks) {
          await _pull(mark, userId);
        }
      } while (_again);
    } finally {
      _running = false;
    }
  }

  /// Sends [displayName] when it has changed since it was last sent, or
  /// always when [force]d (a new membership starts with no name).
  Future<void> _pushName(String? userId, {bool force = false}) async {
    if (userId == null || (!force && displayName == _pushedName)) return;
    await _remote.setMyName(userId, displayName);
    _pushedName = displayName;
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
    final links = <Map<String, dynamic>>[];
    final goneLinks = <({String mealId, String url})>[];

    for (final entry in latest.values) {
      switch (entry.entity) {
        case 'link':
          // "mealId|url"; the id has no bar in it, the address may.
          final bar = entry.rowId.indexOf('|');
          final mealId = entry.rowId.substring(0, bar);
          final url = entry.rowId.substring(bar + 1);
          final recipe = entry.deleted
              ? null
              : await _db.linkedRecipe(mealId: mealId, url: url);
          recipe == null
              ? goneLinks.add((mealId: mealId, url: url))
              : links.add(linkRow(entry.listId, mealId, recipe));
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
    await _remote.upsert(linksTable, links);
    await _remote.tombstone(productsTable, goneProducts);
    await _remote.tombstone(mealsTable, goneMeals);
    for (final link in goneLinks) {
      await _remote.tombstoneLink(mealId: link.mealId, url: link.url);
    }

    // Only what was read: anything queued during the push goes next time.
    await _db.dropOutbox([for (final entry in pending) entry.id]);
  }

  Future<void> _pull(SharedListMark mark, String userId) async {
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
    final links = await _remote.changesSince(linksTable, mark.listId, since);

    await _db.replaceMembers(mark.listId, await _remote.members(mark.listId));

    // A row edited here and not yet pushed keeps the local edit: pulling
    // the server's older copy over it would lose it.
    final pending = await _db.pendingRowIds(mark.listId);
    var newest = mark.cursor;

    // Changes by others since the last pull, for the news. Rows re-read in
    // the overlap were counted last time. The first pull after joining is
    // the whole list arriving, not news; the owner's first pull after
    // sharing is news, since everything in it came from the others.
    final previous = mark.cursor == null ? null : DateTime.parse(mark.cursor!);
    final joining = previous == null && !mark.isOwner;
    final changedBy = <String>{};
    var changes = 0;
    void note(Map<String, dynamic> row) {
      final by = row['updated_by'] as String?;
      if (joining || by == null || by == userId) return;
      if (previous != null &&
          !DateTime.parse(row['updated_at'] as String).isAfter(previous)) {
        return;
      }
      changedBy.add(by);
      changes++;
    }

    await _db.applyingRemote(() async {
      final list = await _db.listById(mark.listId);
      if (list != null && list.name != name && !pending.contains(list.id)) {
        await _db.renameList(list.id, name);
      }

      for (final row in meals) {
        newest = _later(newest, row['updated_at'] as String);
        note(row);
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
        note(row);
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

      // Recipes on the list's meals. Each member keeps a recipe in their
      // own library, so a link that arrives finds the recipe there by its
      // address or adds it, and a link that goes leaves the recipe behind.
      for (final row in links) {
        newest = _later(newest, row['updated_at'] as String);
        note(row);
        final mealId = row['meal_id'] as String;
        final url = row['source_url'] as String;
        if (pending.contains('$mealId|$url')) continue;
        if (await _db.mealById(mealId) == null) continue;

        final mine = await _db.recipeByUrl(userId: userId, sourceUrl: url);
        if (row['deleted_at'] != null) {
          if (mine != null) {
            await _db.unlinkRecipe(mealId: mealId, recipeId: mine.id);
          }
          continue;
        }
        var recipeId = mine?.id;
        if (recipeId == null) {
          recipeId = _uuid.v4();
          await _db.insertRecipe(
            RecipesCompanion.insert(
              id: recipeId,
              userId: Value(userId),
              title: row['title'] as String,
              sourceUrl: url,
              thumbnailUrl: Value(row['thumbnail_url'] as String? ?? ''),
              sourceType: Value(
                row['source_type'] == RecipeSourceType.video.name
                    ? RecipeSourceType.video
                    : RecipeSourceType.web,
              ),
              createdAt: DateTime.now(),
            ),
          );
        }
        await _db.linkRecipe(mealId: mealId, recipeId: recipeId);
      }
    });

    if (newest != null && newest != mark.cursor) {
      await _db.setSharedCursor(mark.listId, newest!);
    }
    if (changes > 0) {
      _news.add(
        SyncNews(
          listId: mark.listId,
          listName: name,
          by: changedBy,
          count: changes,
        ),
      );
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

  static Map<String, dynamic> linkRow(
    String listId,
    String mealId,
    Recipe recipe,
  ) => {
    'list_id': listId,
    'meal_id': mealId,
    'source_url': recipe.sourceUrl,
    'title': recipe.title,
    'thumbnail_url': recipe.thumbnailUrl,
    'source_type': recipe.sourceType.name,
    'deleted_at': null,
  };

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
    changedBy: row['updated_by'] as String?,
    createdAt: _local(row['created_at']),
  );
}

/// Other members changed a shared list.
class SyncNews {
  final String listId;
  final String listName;

  /// Account ids of who changed it.
  final Set<String> by;

  /// How many meals and items changed.
  final int count;

  const SyncNews({
    required this.listId,
    required this.listName,
    required this.by,
    required this.count,
  });
}
