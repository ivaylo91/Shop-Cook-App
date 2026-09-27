import '../../data/local/database.dart';
import '../../data/repositories/recipe_repository.dart';

/// Whether a library recipe matches what was typed into the search.
///
/// Every word has to appear somewhere in the title or the ingredients, so
/// "chicken rice" finds the curry that uses both rather than everything with
/// either. Ingredients come from the cached copy of the page, which is what
/// makes "what can I cook with this courgette" answerable offline.
bool recipeMatches(Recipe recipe, String query) {
  final words = foldName(query)
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;

  final ingredients =
      RecipeRepository.decodeDetails(recipe.details)?.ingredients ?? const [];
  final haystack = foldName([recipe.title, ...ingredients].join('\n'));

  return words.every(haystack.contains);
}
