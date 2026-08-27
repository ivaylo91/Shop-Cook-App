import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeImport {
  final String title;
  final List<String> ingredients;

  /// Human-readable reason the import came back empty, if it did.
  final String? error;

  const RecipeImport({
    this.title = '',
    this.ingredients = const [],
    this.error,
  });

  bool get hasIngredients => ingredients.isNotEmpty;
}

/// Reads a recipe page's ingredient list via the `import-recipe` Edge
/// Function. The work happens server-side because a mobile client cannot
/// fetch arbitrary origins, and because the page needs parsing before it is
/// worth sending over the wire.
class RecipeImportApi {
  final SupabaseClient _client;

  RecipeImportApi(this._client);

  Future<RecipeImport> fetchIngredients(String url) async {
    try {
      final response = await _client.functions.invoke(
        'import-recipe',
        body: {'url': url},
      );
      final data = response.data;
      if (data is! Map) {
        return const RecipeImport(error: 'That page could not be read.');
      }

      final ingredients = (data['ingredients'] as List? ?? const [])
          .whereType<String>()
          .toList();

      return RecipeImport(
        title: data['title'] as String? ?? '',
        ingredients: ingredients,
        error: ingredients.isEmpty
            ? (data['error'] as String? ?? 'No ingredients found there.')
            : null,
      );
    } catch (_) {
      return const RecipeImport(
        error: 'Could not reach the importer. Check your connection.',
      );
    }
  }
}
