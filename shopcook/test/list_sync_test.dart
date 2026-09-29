import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:shopcook/data/remote/shared_list_remote.dart';
import 'package:shopcook/data/repositories/shopping_list_repository.dart';
import 'package:shopcook/data/sync/list_sync.dart';

/// One server, shared by every phone in a test. Mirrors what the real one
/// enforces: membership for every read and write, invites, tombstones, and
/// updated_at stamped by the server.
class _Server {
  final lists = <String, ({String name, String owner})>{};
  final members = <String, Set<String>>{};
  final names = <String, String>{};
  final invites = <String, String>{};
  final rows = <String, Map<String, Map<String, dynamic>>>{
    ListSync.mealsTable: {},
    ListSync.productsTable: {},
  };

  var _tick = 0;

  /// Ten seconds apart, so the pull's five-second overlap re-reads only the
  /// newest change.
  String stamp() => DateTime.utc(
    2026,
    9,
    27,
  ).add(Duration(seconds: 10 * ++_tick)).toIso8601String();
}

class _Remote implements SharedListRemote {
  final _Server server;
  final String userId;

  _Remote(this.server, this.userId);

  void _mustBelong(String listId) {
    if (!(server.members[listId]?.contains(userId) ?? false)) {
      throw StateError('$userId is not a member of $listId');
    }
  }

  @override
  Future<void> createList({required String id, required String name}) async {
    server.lists[id] = (name: name, owner: userId);
    server.members[id] = {userId};
  }

  @override
  Future<String> createInvite(String listId) async {
    _mustBelong(listId);
    final code = 'CODE${server.invites.length}ABC'.substring(0, 8);
    server.invites[code] = listId;
    return code;
  }

  @override
  Future<String?> join(String code) async {
    final listId = server.invites[code];
    if (listId == null || !server.lists.containsKey(listId)) return null;
    server.members[listId]!.add(userId);
    return listId;
  }

  @override
  Future<void> deleteShared(String listId) async {
    if (server.lists[listId]?.owner != userId) throw StateError('not owner');
    server.lists.remove(listId);
    server.members.remove(listId);
    for (final table in server.rows.values) {
      table.removeWhere((_, row) => row['list_id'] == listId);
    }
  }

  @override
  Future<void> leave(String listId, String userId) async =>
      server.members[listId]?.remove(userId);

  @override
  Future<String?> listName(String listId) async {
    if (!(server.members[listId]?.contains(userId) ?? false)) return null;
    return server.lists[listId]?.name;
  }

  @override
  Future<void> renameList(String listId, String name) async {
    _mustBelong(listId);
    server.lists[listId] = (name: name, owner: server.lists[listId]!.owner);
  }

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      _mustBelong(row['list_id'] as String);
      server.rows[table]![row['id'] as String] = {
        ...row,
        'updated_at': server.stamp(),
        'updated_by': userId,
      };
    }
  }

  @override
  Future<void> tombstone(String table, List<String> ids) async {
    for (final id in ids) {
      final row = server.rows[table]![id];
      if (row == null) continue;
      _mustBelong(row['list_id'] as String);
      server.rows[table]![id] = {
        ...row,
        'deleted_at': server.stamp(),
        'updated_at': server.stamp(),
        'updated_by': userId,
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> changesSince(
    String table,
    String listId,
    String? since,
  ) async {
    _mustBelong(listId);
    final found = server.rows[table]!.values
        .where((row) => row['list_id'] == listId)
        .where(
          (row) =>
              since == null ||
              !DateTime.parse(
                row['updated_at'] as String,
              ).isBefore(DateTime.parse(since)),
        )
        .toList()
      ..sort(
        (a, b) =>
            (a['updated_at'] as String).compareTo(b['updated_at'] as String),
      );
    return found;
  }

  @override
  Stream<void> changes() => const Stream.empty();

  @override
  Future<List<({String userId, String name})>> members(String listId) async {
    _mustBelong(listId);
    return [
      for (final member in server.members[listId]!)
        (userId: member, name: server.names[member] ?? ''),
    ];
  }

  @override
  Future<void> setMyName(String userId, String name) async =>
      server.names[userId] = name;
}

/// One phone: its own database, repository and sync, signed in as [user].
class _Phone {
  final String user;
  final AppDatabase db;
  final ShoppingListRepository repo;
  final ListSync sync;

  _Phone._(this.user, this.db, this.repo, this.sync);

  factory _Phone(_Server server, String user) {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    return _Phone._(
      user,
      db,
      ShoppingListRepository(db),
      ListSync(db, _Remote(server, user)),
    );
  }

  Future<void> syncNow() => sync.sync(user);

  Future<List<Product>> items(String listId) =>
      repo.watchAllProducts(listId).first;

  Future<Product> item(String listId, String name) async =>
      (await items(listId)).firstWhere((p) => p.name == name);

  Future<int> outboxSize() => db.watchOutboxSize().first;
}

void main() {
  // Two phones means two databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _Server server;
  late _Phone anna;
  late _Phone ben;

  setUp(() {
    server = _Server();
    anna = _Phone(server, 'anna');
    ben = _Phone(server, 'ben');
  });

  tearDown(() async {
    await anna.db.close();
    await ben.db.close();
  });

  /// Anna makes a list with a meal and two loose items, shares it, and Ben
  /// joins it. Returns the list id.
  Future<String> sharedWeekly() async {
    await anna.repo.createList('Weekly', userId: 'anna');
    final list = (await anna.repo.watchLists('anna').first).single;
    await anna.repo.createMeal(list.id, 'Curry');
    final meal = (await anna.repo.watchMeals(list.id).first).single;
    await anna.repo.addProduct(listId: list.id, mealId: meal.id, name: 'Rice');
    await anna.repo.addProduct(listId: list.id, name: 'Milk');
    await anna.repo.addProduct(listId: list.id, name: 'Bread', quantity: '2');

    final code = await anna.sync.share(list);
    final joined = await ben.sync.join(code, userId: 'ben');
    expect(joined, list.id);
    return list.id;
  }

  test('a joined list arrives whole', () async {
    final listId = await sharedWeekly();

    final benList = (await ben.repo.watchLists('ben').first).single;
    expect(benList.name, 'Weekly');
    expect(
      (await ben.items(listId)).map((p) => p.name),
      unorderedEquals(['Rice', 'Milk', 'Bread']),
    );
    final meal = (await ben.repo.watchMeals(listId).first).single;
    expect(meal.name, 'Curry');
    expect(
      (await ben.repo.watchProductsForMeal(meal.id).first).single.name,
      'Rice',
    );
    expect((await ben.item(listId, 'Bread')).quantity, '2');
  });

  test('a tick on one phone shows on the other, without echoing back',
      () async {
    final listId = await sharedWeekly();

    final milk = await ben.item(listId, 'Milk');
    await ben.repo.toggleProductChecked(milk.id, true);
    expect(await ben.outboxSize(), 1, reason: 'the trigger queued the tick');

    await ben.syncNow();
    expect(await ben.outboxSize(), 0);
    await anna.syncNow();

    expect((await anna.item(listId, 'Milk')).isChecked, isTrue);
    expect(
      await anna.outboxSize(),
      0,
      reason: 'applying a pulled change must not queue it to go back up',
    );
  });

  test('adds, deletes and renames travel both ways', () async {
    final listId = await sharedWeekly();

    await anna.repo.addProduct(listId: listId, name: 'Eggs');
    await anna.repo.deleteProduct((await anna.item(listId, 'Bread')).id);
    await anna.repo.renameList(listId, 'This week');
    await anna.syncNow();
    await ben.syncNow();

    expect(
      (await ben.items(listId)).map((p) => p.name),
      unorderedEquals(['Rice', 'Milk', 'Eggs']),
    );
    expect((await ben.repo.watchLists('ben').first).single.name, 'This week');

    await ben.repo.addProduct(listId: listId, name: 'Coffee');
    await ben.syncNow();
    await anna.syncNow();
    expect(
      (await anna.items(listId)).map((p) => p.name),
      contains('Coffee'),
    );
  });

  test('clearing ticked items and cooking a meal travel too', () async {
    final listId = await sharedWeekly();
    final meal = (await anna.repo.watchMeals(listId).first).single;

    await anna.repo.toggleProductChecked(
      (await anna.item(listId, 'Milk')).id,
      true,
    );
    await anna.repo.clearChecked(listId);
    await anna.repo.markCooked(meal.id);
    await anna.syncNow();
    await ben.syncNow();

    expect((await ben.items(listId)).map((p) => p.name), ['Bread']);
    expect(await ben.repo.watchMeals(listId).first, isEmpty);
    expect((await ben.repo.watchCookedMeals('ben').first).single.name, 'Curry');
  });

  test('a list nobody shared never queues anything', () async {
    await anna.repo.createList('Private', userId: 'anna');
    final list = (await anna.repo.watchLists('anna').first).single;
    await anna.repo.addProduct(listId: list.id, name: 'Chocolate');
    await anna.repo.renameList(list.id, 'Secret');

    expect(await anna.outboxSize(), 0);
    expect(server.rows[ListSync.productsTable], isEmpty);
  });

  test('a wrong code joins nothing', () async {
    expect(await ben.sync.join('WRONG123', userId: 'ben'), isNull);
    expect(await ben.repo.watchLists('ben').first, isEmpty);
  });

  test('when the owner stops sharing, members keep their copy', () async {
    final listId = await sharedWeekly();

    await anna.sync.stopSharing(listId, userId: 'anna');
    await ben.syncNow();

    expect(await ben.db.sharedList(listId), isNull);
    expect(
      (await ben.items(listId)).map((p) => p.name),
      unorderedEquals(['Rice', 'Milk', 'Bread']),
    );
    // And Ben's edits from now on stay on his phone.
    await ben.repo.addProduct(listId: listId, name: 'Tea');
    expect(await ben.outboxSize(), 0);
  });

  test('a member deleting the list leaves it intact for everyone else',
      () async {
    final listId = await sharedWeekly();

    await ben.sync.stopSharing(listId, userId: 'ben');
    await ben.repo.deleteListWithUndo(listId);
    await ben.syncNow();
    await anna.syncNow();

    expect(
      (await anna.items(listId)).map((p) => p.name),
      unorderedEquals(['Rice', 'Milk', 'Bread']),
    );
    expect(server.members[listId], {'anna'});
  });

  test('deleting a shared list locally never deletes it for others',
      () async {
    final listId = await sharedWeekly();

    // Even without leaving first, the cascade must not be queued.
    await ben.repo.deleteListWithUndo(listId);
    expect(await ben.outboxSize(), 0);
    await ben.syncNow();
    await anna.syncNow();

    expect(await anna.items(listId), hasLength(3));
  });

  test('sharing twice hands out a code without re-uploading', () async {
    await anna.repo.createList('Weekly', userId: 'anna');
    final list = (await anna.repo.watchLists('anna').first).single;
    await anna.repo.addProduct(listId: list.id, name: 'Milk');

    await anna.sync.share(list);
    await anna.sync.share(list);

    expect(server.rows[ListSync.productsTable], hasLength(1));
  });

  test('a planned day survives the round trip as the same date', () async {
    final listId = await sharedWeekly();
    final meal = (await anna.repo.watchMeals(listId).first).single;
    await anna.repo.planMeal(meal.id, DateTime(2026, 10, 3));
    await anna.syncNow();
    await ben.syncNow();

    final benMeal = (await ben.repo.watchMeals(listId).first).single;
    expect(benMeal.plannedFor, DateTime(2026, 10, 3));
  });

  test('members see who changed what, by the name they chose', () async {
    anna.sync.displayName = 'Anna';
    ben.sync.displayName = 'Ben';
    final listId = await sharedWeekly();
    final news = <SyncNews>[];
    final listening = anna.sync.news.listen(news.add);
    addTearDown(listening.cancel);

    await ben.repo.toggleProductChecked(
      (await ben.item(listId, 'Milk')).id,
      true,
    );
    await ben.repo.addProduct(listId: listId, name: 'Tea');
    await ben.syncNow();
    await anna.syncNow();
    await pumpEventQueue();

    expect(news.single.by, {'ben'});
    expect(news.single.count, 2);
    expect(news.single.listName, 'Weekly');

    final names = await anna.db.watchMemberNames(listId).first;
    expect(names, {'anna': 'Anna', 'ben': 'Ben'});
    expect((await anna.item(listId, 'Milk')).changedBy, 'ben');
    expect((await anna.item(listId, 'Tea')).changedBy, 'ben');
  });

  test('joining is not news, and neither are your own changes', () async {
    final news = <SyncNews>[];
    final listening = ben.sync.news.listen(news.add);
    addTearDown(listening.cancel);

    final listId = await sharedWeekly();
    await ben.repo.addProduct(listId: listId, name: 'Tea');
    await ben.syncNow();
    await ben.syncNow();
    await pumpEventQueue();

    expect(news, isEmpty);
  });

  test('two syncs at once fold into one pass after another', () async {
    final listId = await sharedWeekly();
    await ben.repo.addProduct(listId: listId, name: 'Tea');

    await Future.wait([ben.syncNow(), ben.syncNow(), ben.syncNow()]);
    expect(await ben.outboxSize(), 0);
    expect(
      server.rows[ListSync.productsTable]!.values.where(
        (row) => row['name'] == 'Tea',
      ),
      hasLength(1),
    );
  });
}
