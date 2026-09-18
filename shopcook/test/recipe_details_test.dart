import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:shopcook/data/remote/recipe_import_api.dart';
import 'package:shopcook/data/remote/recipe_search_api.dart';
import 'package:shopcook/data/repositories/recipe_repository.dart';

const _url = 'https://www.bonapeti.bg/recepti/chili-kon-karne/';
const _user = 'user-1';

const _chilli = RecipeImport(
  title: 'Чили кон карне',
  ingredients: ['600 г кайма', '1 глава лук'],
  steps: ['Запържете каймата.', 'Гответе 40 минути.'],
  servings: '6',
  minutes: 150,
  image: 'https://example.com/chilli.jpg',
);

void main() {
  late AppDatabase db;
  late _FakeImport importer;
  late RecipeRepository recipes;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = _FakeImport();
    recipes = RecipeRepository(db, _NoSearch(), importApi: importer);
  });

  tearDown(() => db.close());

  Future<Recipe> saved({String title = ''}) async {
    importer.next = const RecipeImport(failure: ImportFailure.unreachable);
    final id = await recipes.saveRecipe(
      userId: _user,
      title: title,
      sourceUrl: _url,
    );
    await pumpEventQueue();
    importer.calls = 0;
    return (await db.recipeById(id))!;
  }

  test('reads the page once, then answers from the saved copy', () async {
    final recipe = await saved(title: 'Chilli');
    importer.next = _chilli;

    final first = await recipes.details(recipe);
    expect(first.steps, _chilli.steps);
    expect(importer.calls, 1);

    // Offline now: the kitchen has no signal.
    importer.next = const RecipeImport(failure: ImportFailure.unreachable);
    final second = await recipes.details(recipe);
    expect(importer.calls, 1, reason: 'no second fetch');
    expect(second.ingredients, _chilli.ingredients);
    expect(second.servings, '6');
    expect(second.minutes, 150);
  });

  test('a failed refresh keeps the saved copy', () async {
    final recipe = await saved(title: 'Chilli');
    importer.next = _chilli;
    await recipes.details(recipe);

    importer.next = const RecipeImport(failure: ImportFailure.unreachable);
    final refreshed = await recipes.details(recipe, refresh: true);
    expect(importer.calls, 2);
    expect(refreshed.steps, _chilli.steps);
  });

  test('a never-read recipe offline reports unreachable', () async {
    final recipe = await saved(title: 'Chilli');
    final result = await recipes.details(recipe);
    expect(result.hasIngredients, isFalse);
    expect(result.failure, ImportFailure.unreachable);
  });

  test('a link saved without a title takes the page title', () async {
    final recipe = await saved();
    expect(recipe.title, _url);

    importer.next = _chilli;
    await recipes.details(recipe);
    expect((await db.recipeById(recipe.id))!.title, 'Чили кон карне');
  });

  test('a title the user typed is left alone', () async {
    final recipe = await saved(title: 'Mum’s chilli');
    importer.next = _chilli;
    await recipes.details(recipe);
    expect((await db.recipeById(recipe.id))!.title, 'Mum’s chilli');
  });

  test('saving a web link reads it straight away', () async {
    importer.next = _chilli;
    final id = await recipes.saveRecipe(
      userId: _user,
      title: '',
      sourceUrl: _url,
    );
    await pumpEventQueue();

    final row = (await db.recipeById(id))!;
    expect(row.title, 'Чили кон карне');
    expect(RecipeRepository.decodeDetails(row.details)?.steps, _chilli.steps);
  });

  test('a video is not sent to the page reader', () async {
    importer.next = _chilli;
    await recipes.saveRecipe(
      userId: _user,
      title: 'Video',
      sourceUrl: 'https://youtu.be/abc',
      sourceType: RecipeSourceType.video,
    );
    await pumpEventQueue();
    expect(importer.calls, 0);
  });

  test('fillMissingDetails reads unread web recipes, once each', () async {
    final unread = await saved();
    importer.next = _chilli;

    await recipes.fillMissingDetails([unread]);
    expect(importer.calls, 1);
    final filled = (await db.recipeById(unread.id))!;
    expect(filled.title, 'Чили кон карне');

    // Already read: skipped. Tried before this session: skipped too.
    await recipes.fillMissingDetails([filled, unread]);
    expect(importer.calls, 1);
  });

  test('fillMissingDetails does not retry a failure in the same session',
      () async {
    final unread = await saved();
    await recipes.fillMissingDetails([unread]);
    await recipes.fillMissingDetails([unread]);
    expect(importer.calls, 1);
  });

  test('the page picture becomes the thumbnail when there is none', () async {
    final recipe = await saved(title: 'Chilli');
    importer.next = _chilli;
    await recipes.details(recipe);
    expect(
      (await db.recipeById(recipe.id))!.thumbnailUrl,
      'https://example.com/chilli.jpg',
    );
  });

  test('a thumbnail the recipe already has is kept', () async {
    importer.next = const RecipeImport(failure: ImportFailure.unreachable);
    final id = await recipes.saveRecipe(
      userId: _user,
      title: 'Chilli',
      sourceUrl: _url,
      thumbnailUrl: 'https://i.ytimg.com/own.jpg',
    );
    await pumpEventQueue();
    importer.next = _chilli;
    await recipes.details((await db.recipeById(id))!);
    expect((await db.recipeById(id))!.thumbnailUrl, 'https://i.ytimg.com/own.jpg');
  });

  test('a recipe read before pictures existed is read again once', () async {
    final recipe = await saved(title: 'Chilli');
    importer.next = const RecipeImport(
      ingredients: ['600 г кайма'],
      steps: ['Гответе.'],
    );
    await recipes.details(recipe);
    importer.calls = 0;

    importer.next = _chilli;
    final stale = (await db.recipeById(recipe.id))!;
    await recipes.fillMissingDetails([stale]);
    expect(importer.calls, 1);
    expect(
      (await db.recipeById(recipe.id))!.thumbnailUrl,
      'https://example.com/chilli.jpg',
    );
  });

  test('youtubeThumbnail reads the id from every link shape', () {
    const still = 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg';
    for (final link in [
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42',
      'https://youtu.be/dQw4w9WgXcQ?si=abc',
      'https://m.youtube.com/shorts/dQw4w9WgXcQ',
      'https://www.youtube.com/embed/dQw4w9WgXcQ',
    ]) {
      expect(RecipeRepository.youtubeThumbnail(link), still, reason: link);
    }
    expect(RecipeRepository.youtubeThumbnail('https://example.com/x'), '');
    expect(RecipeRepository.youtubeThumbnail('https://youtu.be/short'), '');
  });

  test('a pasted video gets its picture, on save and after', () async {
    final id = await recipes.saveRecipe(
      userId: _user,
      title: 'Мусака',
      sourceUrl: 'https://youtu.be/dQw4w9WgXcQ',
      sourceType: RecipeSourceType.video,
    );
    expect(
      (await db.recipeById(id))!.thumbnailUrl,
      'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
    );

    // One saved before this existed.
    await db.setRecipeThumbnail(id, '');
    await recipes.fillMissingDetails([(await db.recipeById(id))!]);
    expect((await db.recipeById(id))!.thumbnailUrl, isNotEmpty);
    expect(importer.calls, 0, reason: 'no page read for a video');

    // A letterboxed still, as search results carry, is swapped.
    await db.setRecipeThumbnail(
      id,
      'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    );
    await recipes.fillMissingDetails([(await db.recipeById(id))!]);
    expect(
      (await db.recipeById(id))!.thumbnailUrl,
      'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
    );
  });

  test('an unreadable saved copy counts as none', () {
    expect(RecipeRepository.decodeDetails('not json'), isNull);
    expect(RecipeRepository.decodeDetails('{"ingredients": []}'), isNull);
    expect(RecipeRepository.decodeDetails(null), isNull);
  });
}

class _FakeImport implements RecipeImportApi {
  RecipeImport next = const RecipeImport(failure: ImportFailure.unreachable);
  int calls = 0;

  @override
  Future<RecipeImport> fetchIngredients(String url) async {
    calls++;
    return next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSearch implements RecipeSearchApi {
  @override
  Future<List<RecipeSearchResult>> search(
    String query, {
    String locale = 'en',
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
