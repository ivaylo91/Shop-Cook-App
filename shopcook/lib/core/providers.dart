import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/database.dart';
import '../data/remote/recipe_import_api.dart';
import '../data/remote/recipe_search_api.dart';
import '../data/remote/shared_list_remote.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/repositories/shopping_list_repository.dart';
import '../data/sync/list_sync.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Re-emits whenever Supabase reports a sign-in, sign-out or token refresh.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The signed-in user's id, or null. Everything stored locally is scoped by
/// this, so two people signing in on one phone no longer see each other's
/// lists.
final currentUserIdProvider = Provider<String?>((ref) {
  // Watched only to rebuild when auth changes; the id itself is read from the
  // client, which is the authority and is already restored at startup.
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser?.id;
});

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
    importApi: ref.watch(recipeImportApiProvider),
  );
});

final listSyncProvider = Provider<ListSync>((ref) {
  return ListSync(
    ref.watch(databaseProvider),
    SupabaseSharedListRemote(Supabase.instance.client),
  );
});

/// Which lists are shared, and whether this user shared each one.
final sharedListsProvider = StreamProvider<Map<String, bool>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchSharedLists()
      .map((marks) => {for (final m in marks) m.listId: m.isOwner});
});

/// Member names of a shared list, by account id.
final memberNamesProvider = StreamProvider.family<Map<String, String>, String>((
  ref,
  listId,
) {
  return ref.watch(databaseProvider).watchMemberNames(listId);
});
