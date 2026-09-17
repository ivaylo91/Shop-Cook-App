import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../remote/recipe_search_api.dart';

const _uuid = Uuid();

/// How long a cached search stays good for.
///
/// Recipe videos do not go stale in hours, and the cost of being a day behind
/// is nil next to the cost of the quota running out mid-week.
const _cacheLifetime = Duration(days: 7);

class RecipeRepository {
  final AppDatabase _db;
  final RecipeSearchApi _searchApi;

  RecipeRepository(this._db, this._searchApi);

  Stream<List<Recipe>> watchRecipesForMeal(String mealId) =>
      _db.watchRecipesForMeal(mealId);

  /// Searches for recipes, answering from the local cache when it can.
  ///
  /// A YouTube `search.list` call costs 100 units of a 10,000-unit daily
  /// quota, and both recipe screens search the moment they open. Without a
  /// cache, reopening the same item a hundred times in a day exhausts the key
  /// — and the Edge Function reports a missing quota exactly as it reports a
  /// missing key, so it would look like the key had come unset.
  ///
  /// Caching also makes the screen work offline for anything looked up
  /// before, which the shop-with-no-signal case cares about.
  Future<List<RecipeSearchResult>> search(
    String query, {
    required String locale,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(query);
    if (key.isEmpty) return const [];

    if (!forceRefresh) {
      final cached = await _db.cachedSearch(key, locale);
      if (cached != null && _isFresh(cached)) {
        final results = _decode(cached.payload);
        // An empty cached result is still an answer, but a cheap one to get
        // wrong: it is what an unconfigured key produces, so it is not worth
        // remembering in place of a real search.
        if (results.isNotEmpty) return results;
      }
    }

    final fresh = await _searchApi.search(query, locale: locale);

    // Only a real result set is worth storing. Caching emptiness would pin
    // "no recipes" in place for a week after a transient failure.
    if (fresh.isNotEmpty) {
      await _db.cacheSearch(
        RecipeSearchesCompanion.insert(
          query: key,
          locale: locale,
          payload: _encode(fresh),
          fetchedAt: DateTime.now(),
        ),
      );
      // Opportunistic: there is no background work in this app, and a stale
      // row costs nothing until someone asks for that query again.
      await _db.pruneSearchCache(DateTime.now().subtract(_cacheLifetime * 4));
    }

    return fresh;
  }

  static String _cacheKey(String query) => query.trim().toLowerCase();

  static bool _isFresh(CachedSearch row) =>
      DateTime.now().difference(row.fetchedAt) < _cacheLifetime;

  static String _encode(List<RecipeSearchResult> results) => jsonEncode([
    for (final r in results)
      {
        'type': r.type == RecipeResultType.video ? 'video' : 'web',
        'title': r.title,
        'thumbnailUrl': r.thumbnailUrl,
        'url': r.url,
        'source': r.source,
      },
  ]);

  static List<RecipeSearchResult> _decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecipeSearchResult.fromJson)
          .toList();
    } catch (_) {
      // A row written by an older version, or corrupt. Treat it as a miss
      // rather than letting one bad row break the screen.
      return const [];
    }
  }

  /// The user's library, newest first.
  Stream<List<LibraryRecipe>> watchLibrary(String userId) =>
      _db.watchLibrary(userId);

  Future<List<({Meal meal, String listName})>> mealsForUser(String userId) =>
      _db.mealsForUser(userId);

  /// Saves a recipe to the library without putting it on any meal, reusing
  /// the existing entry when this link is already saved. Returns its id.
  Future<String> saveRecipe({
    required String userId,
    required String title,
    required String sourceUrl,
    String thumbnailUrl = '',
    RecipeSourceType sourceType = RecipeSourceType.web,
  }) async {
    final url = sourceUrl.trim();
    final existing = await _db.recipeByUrl(userId: userId, sourceUrl: url);
    if (existing != null) return existing.id;

    final id = _uuid.v4();
    await _db.insertRecipe(
      RecipesCompanion.insert(
        id: id,
        userId: Value(userId),
        title: title.trim().isEmpty ? url : title.trim(),
        sourceUrl: url,
        thumbnailUrl: Value(thumbnailUrl),
        sourceType: Value(sourceType),
        createdAt: DateTime.now(),
      ),
    );
    return id;
  }

  /// Saves (or reuses) a recipe and puts it on [mealId].
  Future<void> attachRecipe({
    required String mealId,
    required String userId,
    required String title,
    required String sourceUrl,
    String thumbnailUrl = '',
    RecipeSourceType sourceType = RecipeSourceType.web,
  }) async {
    final recipeId = await saveRecipe(
      userId: userId,
      title: title,
      sourceUrl: sourceUrl,
      thumbnailUrl: thumbnailUrl,
      sourceType: sourceType,
    );
    await _db.linkRecipe(mealId: mealId, recipeId: recipeId);
  }

  Future<void> attachFromSearchResult({
    required String mealId,
    required String userId,
    required RecipeSearchResult result,
  }) {
    return attachRecipe(
      mealId: mealId,
      userId: userId,
      title: result.title,
      sourceUrl: result.url,
      thumbnailUrl: result.thumbnailUrl,
      sourceType: _typeOf(result),
    );
  }

  Future<String> saveSearchResult({
    required String userId,
    required RecipeSearchResult result,
  }) {
    return saveRecipe(
      userId: userId,
      title: result.title,
      sourceUrl: result.url,
      thumbnailUrl: result.thumbnailUrl,
      sourceType: _typeOf(result),
    );
  }

  /// Puts an already-saved recipe on a meal.
  Future<void> linkToMeal({required String mealId, required String recipeId}) =>
      _db.linkRecipe(mealId: mealId, recipeId: recipeId);

  /// Takes a recipe off one meal. It stays in the library.
  Future<void> detachFromMeal({
    required String mealId,
    required String recipeId,
  }) => _db.unlinkRecipe(mealId: mealId, recipeId: recipeId);

  /// Removes a recipe from the library and from every meal using it.
  Future<void> deleteRecipe(String id) => _db.deleteRecipe(id);

  static RecipeSourceType _typeOf(RecipeSearchResult result) =>
      result.type == RecipeResultType.video
      ? RecipeSourceType.video
      : RecipeSourceType.web;

  /// Guesses the type of a pasted link: YouTube links play in the app's
  /// player, anything else opens as a web page.
  static RecipeSourceType typeOfUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    return host.endsWith('youtube.com') || host == 'youtu.be'
        ? RecipeSourceType.video
        : RecipeSourceType.web;
  }
}
