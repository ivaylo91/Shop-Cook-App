import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../remote/recipe_search_api.dart';

const _uuid = Uuid();

class RecipeRepository {
  final AppDatabase _db;
  final RecipeSearchApi _searchApi;

  RecipeRepository(this._db, this._searchApi);

  Stream<List<Recipe>> watchRecipesForMeal(String mealId) =>
      _db.watchRecipesForMeal(mealId);

  Future<List<RecipeSearchResult>> search(String query) =>
      _searchApi.search(query);

  Future<void> attachRecipe({
    required String mealId,
    required String title,
    required String sourceUrl,
    String thumbnailUrl = '',
    RecipeSourceType sourceType = RecipeSourceType.web,
  }) {
    return _db.insertRecipe(
      RecipesCompanion.insert(
        id: _uuid.v4(),
        mealId: mealId,
        title: title,
        sourceUrl: sourceUrl,
        thumbnailUrl: Value(thumbnailUrl),
        sourceType: Value(sourceType),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> attachFromSearchResult(String mealId, RecipeSearchResult r) {
    return attachRecipe(
      mealId: mealId,
      title: r.title,
      sourceUrl: r.url,
      thumbnailUrl: r.thumbnailUrl,
      sourceType: r.type == RecipeResultType.video
          ? RecipeSourceType.video
          : RecipeSourceType.web,
    );
  }

  Future<void> deleteRecipe(String id) => _db.deleteRecipe(id);
}
