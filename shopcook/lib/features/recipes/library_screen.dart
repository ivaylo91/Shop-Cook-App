import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/repositories/recipe_repository.dart';
import 'recipe_link_dialog.dart';
import 'recipe_thumbnail.dart';

/// Every recipe the user has kept, independent of any meal.
///
/// Recipes used to belong to exactly one meal and vanish with it, so the
/// bolognese found last month had to be found again this month. Here it
/// stays, and goes onto as many meals as it is cooked for.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final libraryAsync = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navRecipes),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.link, size: 17),
            tooltip: l10n.libraryAddLink,
            onPressed: () => addLinkToLibrary(context, ref),
          ),
        ],
      ),
      body: libraryAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: SkeletonRows(count: 3),
        ),
        error: (_, __) => ErrorState(
          onRetry: () => ref.invalidate(libraryProvider),
        ),
        data: (library) {
          if (library.isEmpty) {
            return EmptyState(
              icon: FontAwesomeIcons.bookOpen,
              title: l10n.libraryEmptyTitle,
              message: l10n.libraryEmptyMessage,
              actionLabel: l10n.libraryAddLink,
              actionIcon: FontAwesomeIcons.link,
              onAction: () => addLinkToLibrary(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(Insets.lg),
            itemCount: library.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
            itemBuilder: (context, index) =>
                _LibraryCard(entry: library[index]),
          );
        },
      ),
    );
  }
}

/// Asks for a link and saves it to the library. Public so the share-sheet
/// intake can land a shared link in the same place.
Future<void> addLinkToLibrary(
  BuildContext context,
  WidgetRef ref, {
  String initialUrl = '',
  String initialTitle = '',
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  final link = await promptForRecipeLink(
    context,
    initialUrl: initialUrl,
    title: initialTitle,
  );
  if (link == null) return;

  await ref.read(recipeRepositoryProvider).saveRecipe(
    userId: userId,
    title: link.title,
    sourceUrl: link.url,
    sourceType: RecipeRepository.typeOfUrl(link.url),
  );

  messenger.showSnackBar(SnackBar(content: Text(l10n.librarySaved)));
}

class _LibraryCard extends ConsumerWidget {
  final LibraryRecipe entry;

  const _LibraryCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final recipe = entry.recipe;
    final isVideo = recipe.sourceType == RecipeSourceType.video;

    return AppCard(
      padding: const EdgeInsets.all(Insets.md),
      tint: palette.ink,
      shadowOpacity: 0.06,
      onTap: () => context.push('/recipe', extra: recipe),
      onLongPress: () => _actions(context, ref),
      child: Row(
        children: [
          RecipeThumbnail(url: recipe.thumbnailUrl, isVideo: isVideo),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: AppText.body.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  isVideo ? l10n.recipeSourceVideo : l10n.recipeSourceWeb,
                  style: AppText.caption.copyWith(color: palette.inkMuted),
                ),
                Text(
                  l10n.libraryUsedIn(entry.mealCount),
                  style: AppText.caption.copyWith(color: palette.inkFaint),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 15),
            tooltip: l10n.itemActions,
            onPressed: () => _actions(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;

    final action = await showAppSheet<String>(
      context: context,
      title: entry.recipe.title,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.recipe.sourceType != RecipeSourceType.video)
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.kitchenSet, size: 16),
              title: Text(l10n.cookModeStart),
              onTap: () => Navigator.pop(context, 'cook'),
            ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.utensils, size: 16),
            title: Text(l10n.libraryAddToMeal),
            onTap: () => Navigator.pop(context, 'meal'),
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.trashCan, size: 16, color: error),
            title: Text(
              l10n.libraryDeleteForGood,
              style: TextStyle(color: error),
            ),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'cook':
        await context.push('/cook', extra: entry.recipe);
      case 'meal':
        await _addToMeal(context, ref);
      case 'delete':
        await _delete(context, ref);
    }
  }

  Future<void> _addToMeal(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(recipeRepositoryProvider);
    final meals = await repository.mealsForUser(userId);
    if (!context.mounted) return;

    if (meals.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.libraryNoMeals)));
      return;
    }

    final picked = await showAppSheet<Meal>(
      context: context,
      title: l10n.libraryPickMeal,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in meals)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.utensils, size: 16),
                title: Text(option.meal.name),
                // Meal names repeat across weeks; the list says which one.
                subtitle: Text(option.listName),
                onTap: () => Navigator.pop(context, option.meal),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;

    await repository.linkToMeal(mealId: picked.id, recipeId: entry.recipe.id);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.libraryAdded(picked.name))),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await confirmAction(
      context,
      title: l10n.libraryDeleteTitle,
      message: l10n.libraryDeleteMessage,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;

    await ref.read(recipeRepositoryProvider).deleteRecipe(entry.recipe.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.libraryDeleted)));
  }
}

final libraryProvider = StreamProvider<List<LibraryRecipe>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(recipeRepositoryProvider).watchLibrary(userId);
});
