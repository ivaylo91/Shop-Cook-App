import 'package:supabase_flutter/supabase_flutter.dart';

/// Why an import came back with nothing.
///
/// A code rather than a sentence: this runs with no BuildContext and so no
/// locale, and the wording belongs to the screen that shows it.
enum ImportFailure {
  /// The function replied, but the page had no ingredient list it could read.
  noneFound,

  /// The function replied that it could not read the page at all.
  unreadable,

  /// Never reached the function.
  unreachable,
}

class RecipeImport {
  final String title;
  final List<String> ingredients;

  /// Why it came back empty, if it did.
  final ImportFailure? failure;

  const RecipeImport({
    this.title = '',
    this.ingredients = const [],
    this.failure,
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
        return const RecipeImport(failure: ImportFailure.unreadable);
      }

      final ingredients = (data['ingredients'] as List? ?? const [])
          .whereType<String>()
          .toList();

      return RecipeImport(
        title: data['title'] as String? ?? '',
        ingredients: ingredients,
        failure: ingredients.isEmpty ? ImportFailure.noneFound : null,
      );
    } catch (_) {
      return const RecipeImport(failure: ImportFailure.unreachable);
    }
  }
}
