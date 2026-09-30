import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The server side of shared lists: the `shared_*` tables and the invite
/// functions (see supabase/migrations/20260927130000_shared_lists.sql).
///
/// An interface so the sync can be tested against an in-memory server with
/// two phones talking through it.
abstract class SharedListRemote {
  /// Puts a list on the server, owned by the signed-in user. Doing it
  /// again for a list that is already there changes nothing.
  Future<void> createList({required String id, required String name});

  /// An invite code for a list the user belongs to.
  Future<String> createInvite(String listId);

  /// Joins the list [code] points at and returns its id, or null when the
  /// code is wrong, expired, or its list is gone.
  Future<String?> join(String code);

  /// Removes the list from the server for every member. Owner only.
  Future<void> deleteShared(String listId);

  /// Takes [userId] out of the list's members.
  Future<void> leave(String listId, String userId);

  /// The list's name, or null when it is no longer shared with this user.
  Future<String?> listName(String listId);

  Future<void> renameList(String listId, String name);

  /// Inserts or overwrites rows of `shared_meals` or `shared_products`.
  Future<void> upsert(String table, List<Map<String, dynamic>> rows);

  /// Marks rows deleted, so other phones learn they went.
  Future<void> tombstone(String table, List<String> ids);

  /// Marks a meal's use of the recipe at [url] as removed. Recipe links
  /// have no id of their own; the meal and the address identify one.
  Future<void> tombstoneLink({required String mealId, required String url});

  /// Rows of one list changed at or after [since] (a server timestamp), or
  /// every row when [since] is null, oldest change first.
  Future<List<Map<String, dynamic>>> changesSince(
    String table,
    String listId,
    String? since,
  );

  /// Fires whenever something in a list this user belongs to changes.
  Stream<void> changes();

  /// Who belongs to the list, with the name each chose (empty if none).
  Future<List<({String userId, String name})>> members(String listId);

  /// Sets the name [userId] shows under in every list they belong to.
  Future<void> setMyName(String userId, String name);
}

class SupabaseSharedListRemote implements SharedListRemote {
  final SupabaseClient _client;

  SupabaseSharedListRemote(this._client);

  @override
  Future<void> createList({required String id, required String name}) async {
    try {
      await _client.from('shared_lists').insert({'id': id, 'name': name});
    } on PostgrestException catch (error) {
      // 23505 is "already exists": an earlier share got this far and no
      // further, which makes this attempt a retry, not a failure. A plain
      // insert rather than an upsert that ignores duplicates, because the
      // upsert form is checked against the read policy before the trigger
      // has made the creator a member, and is refused.
      if (error.code != '23505') rethrow;
    }
  }

  @override
  Future<String> createInvite(String listId) async =>
      await _client.rpc('create_list_invite', params: {'target': listId})
          as String;

  @override
  Future<String?> join(String code) async {
    try {
      return await _client.rpc('join_list', params: {'invite': code})
          as String?;
    } on PostgrestException catch (error) {
      // P0002 is the function's "no such invite".
      if (error.code == 'P0002') return null;
      rethrow;
    }
  }

  @override
  Future<void> deleteShared(String listId) =>
      _client.rpc('delete_shared_list', params: {'target': listId});

  @override
  Future<void> leave(String listId, String userId) => _client
      .from('shared_list_members')
      .delete()
      .eq('list_id', listId)
      .eq('user_id', userId);

  @override
  Future<String?> listName(String listId) async {
    final row = await _client
        .from('shared_lists')
        .select('name')
        .eq('id', listId)
        .maybeSingle();
    return row?['name'] as String?;
  }

  @override
  Future<void> renameList(String listId, String name) =>
      _client.from('shared_lists').update({'name': name}).eq('id', listId);

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from(table).upsert(rows);
  }

  @override
  Future<void> tombstone(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from(table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids);
  }

  @override
  Future<void> tombstoneLink({required String mealId, required String url}) =>
      _client
          .from('shared_meal_recipes')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('meal_id', mealId)
          .eq('source_url', url);

  @override
  Future<List<Map<String, dynamic>>> changesSince(
    String table,
    String listId,
    String? since,
  ) async {
    var query = _client.from(table).select().eq('list_id', listId);
    if (since != null) query = query.gte('updated_at', since);
    return await query.order('updated_at');
  }

  @override
  Future<List<({String userId, String name})>> members(String listId) async {
    final rows = await _client
        .from('shared_list_members')
        .select('user_id, display_name')
        .eq('list_id', listId);
    return [
      for (final row in rows)
        (
          userId: row['user_id'] as String,
          name: row['display_name'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<void> setMyName(String userId, String name) => _client
      .from('shared_list_members')
      .update({'display_name': name})
      .eq('user_id', userId);

  @override
  Stream<void> changes() {
    late final RealtimeChannel channel;
    final controller = StreamController<void>(
      onCancel: () => _client.removeChannel(channel),
    );
    channel = _client.channel('shared-lists');
    for (final table in [
      'shared_lists',
      'shared_meals',
      'shared_products',
      'shared_meal_recipes',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => controller.add(null),
      );
    }
    channel.subscribe();
    return controller.stream;
  }
}
