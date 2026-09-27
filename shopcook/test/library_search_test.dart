import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:shopcook/data/remote/recipe_import_api.dart';
import 'package:shopcook/data/repositories/recipe_repository.dart';
import 'package:shopcook/features/recipes/library_search.dart';

Recipe _recipe(String title, {List<String> ingredients = const []}) => Recipe(
  id: title,
  title: title,
  sourceUrl: 'https://example.com/$title',
  thumbnailUrl: '',
  sourceType: RecipeSourceType.web,
  createdAt: DateTime(2026),
  details: ingredients.isEmpty
      ? null
      : RecipeRepository.encodeDetails(
          RecipeImport(title: title, ingredients: ingredients),
        ),
);

void main() {
  final curry = _recipe(
    'Thai green curry',
    ingredients: ['400 g chicken thighs', '1 cup jasmine rice'],
  );
  final musaka = _recipe(
    'Мусака',
    ingredients: ['500 г Картофи', '400 г кайма'],
  );

  test('an empty query matches everything', () {
    expect(recipeMatches(curry, ''), isTrue);
    expect(recipeMatches(curry, '   '), isTrue);
  });

  test('matches the title, ignoring case', () {
    expect(recipeMatches(curry, 'CURRY'), isTrue);
    expect(recipeMatches(curry, 'soup'), isFalse);
  });

  test('matches ingredients from the cached page', () {
    expect(recipeMatches(curry, 'chicken'), isTrue);
    expect(recipeMatches(musaka, 'картофи'), isTrue,
        reason: 'Cyrillic case folds too');
  });

  test('every word has to match somewhere', () {
    expect(recipeMatches(curry, 'chicken rice'), isTrue);
    expect(recipeMatches(curry, 'chicken beef'), isFalse);
  });

  test('a recipe never read offline matches on its title alone', () {
    final bare = _recipe('Pancakes');
    expect(recipeMatches(bare, 'pancake'), isTrue);
    expect(recipeMatches(bare, 'flour'), isFalse);
  });
}
