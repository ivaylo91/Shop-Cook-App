import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/database.dart';
import '../data/remote/recipe_import_api.dart';
import '../data/remote/recipe_search_api.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/repositories/shopping_list_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((
  ref,
) {
  return ShoppingListRepository(ref.watch(databaseProvider));
});

final recipeSearchApiProvider = Provider<RecipeSearchApi>((ref) {
  return RecipeSearchApi(Supabase.instance.client);
});

final recipeImportApiProvider = Provider<RecipeImportApi>((ref) {
  return RecipeImportApi(Supabase.instance.client);
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(
    ref.watch(databaseProvider),
    ref.watch(recipeSearchApiProvider),
  );
});
