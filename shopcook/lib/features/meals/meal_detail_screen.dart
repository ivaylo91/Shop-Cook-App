import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/repositories/shopping_list_repository.dart';
import '../products/item_composer.dart';
import '../recipes/import_ingredients_sheet.dart';
import '../shopping/product_category.dart';

class MealDetailScreen extends ConsumerWidget {
  final String listId;
  final Meal meal;

  const MealDetailScreen({super.key, required this.listId, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final productsAsync = ref.watch(_mealProductsProvider(meal.id));
    final recipesAsync = ref.watch(_mealRecipesProvider(meal.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(meal.name),
        actions: [
          IconButton(
            icon: FaIcon(
              meal.plannedFor == null
                  ? FontAwesomeIcons.calendarPlus
                  : FontAwesomeIcons.calendarCheck,
              size: 17,
            ),
            tooltip: meal.plannedFor == null
                ? l10n.mealPlanDay
                : l10n.mealPlannedFor(
                    DateFormat('EEE d MMM', locale).format(meal.plannedFor!),
                  ),
            onPressed: () => _plan(context, ref),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 17),
            tooltip: l10n.mealFindRecipe,
            onPressed: () => context.push(
              '/list/$listId/meal/${meal.id}/search',
              extra: meal,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                Insets.xl,
              ),
              children: [
                SectionLabel(
                  icon: FontAwesomeIcons.carrot,
                  label: l10n.mealIngredients,
                  // Null rather than 0: a bare "0" beside a heading whose
                  // own empty state already says so is just noise.
                  count: switch (productsAsync.valueOrNull?.length) {
                    null || 0 => null,
                    final count => count,
                  },
                  color: palette.accent,
                ),
                const SizedBox(height: Insets.md),
                productsAsync.when(
                  loading: () => const SkeletonRows(count: 3),
                  error: (_, __) => ErrorState(
                    title: l10n.mealIngredientsError,
                    onRetry: () => ref.invalidate(_mealProductsProvider(meal.id)),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return InlineNote(
                        message: l10n.mealIngredientsEmpty,
                      );
                    }
                    return AppCardList(
                      tint: palette.accent,
                      children: [
                        for (final product in products)
                          ProductRow(
                            name: product.name,
                            details: '${product.quantity} ${product.unit}'.trim(),
                            checked: product.isChecked,
                            onToggle: (value) => ref
                                .read(shoppingListRepositoryProvider)
                                .toggleProductChecked(product.id, value),
                            onLongPress: () =>
                                _itemActions(context, ref, product),
                            trailing: IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.ellipsisVertical,
                                size: 16,
                              ),
                              tooltip: l10n.itemActions,
                              onPressed: () => _itemActions(context, ref, product),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: Insets.xl),
                SectionLabel(
                  icon: FontAwesomeIcons.bookOpen,
                  label: l10n.mealRecipe,
                  color: palette.aisle(_recipeSectionHue),
                ),
                const SizedBox(height: Insets.md),
                recipesAsync.when(
                  loading: () => const SkeletonRows(count: 1),
                  error: (_, __) => ErrorState(
                    title: l10n.mealRecipeError,
                    onRetry: () => ref.invalidate(_mealRecipesProvider(meal.id)),
                  ),
                  data: (recipes) {
                    if (recipes.isEmpty) {
                      return InlineNote(message: l10n.mealRecipeEmpty);
                    }
                    return Column(
                      children: [
                        for (final recipe in recipes) ...[
                          _RecipeCard(
                            recipe: recipe,
                            listId: listId,
                            mealId: meal.id,
                          ),
                          const SizedBox(height: Insets.md),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          ItemComposer(
            listId: listId,
            mealId: meal.id,
            hintText: l10n.mealComposerHint,
          ),
        ],
      ),
    );
  }

  /// Gives the meal a day, or takes it off the plan.
  ///
  /// The screen is handed a snapshot of the meal, so the date it shows comes
  /// from that snapshot; the Plan tab reads the live row.
  Future<void> _plan(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = ShoppingListRepository.dayOf(DateTime.now());
    final repository = ref.read(shoppingListRepositoryProvider);

    if (meal.plannedFor != null) {
      final action = await showAppSheet<String>(
        context: context,
        title: meal.name,
        subtitle: l10n.mealPlannedFor(
          DateFormat('EEEE d MMM', locale).format(meal.plannedFor!),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.calendarDay, size: 16),
              title: Text(l10n.mealMoveDay),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.calendarXmark, size: 16),
              title: Text(l10n.mealClearDay),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
          ],
        ),
      );

      if (action == null || !context.mounted) return;
      if (action == 'clear') {
        await repository.planMeal(meal.id, null);
        return;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: meal.plannedFor ?? today,
      firstDate: DateTime(today.year, today.month, today.day - 30),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: l10n.mealCookOn(meal.name),
    );

    if (picked == null) return;
    await repository.planMeal(meal.id, picked);
  }

  Future<void> _itemActions(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final l10n = context.l10n;
    final action = await showAppSheet<String>(
      context: context,
      title: product.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 17),
            title: Text(l10n.itemFindRecipes),
            subtitle: Text(l10n.itemFindRecipesFromMeal),
            onTap: () => Navigator.pop(context, 'recipes'),
          ),
          ListTile(
            leading: FaIcon(
              FontAwesomeIcons.trashCan,
              size: 17,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.actionDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );

    if (action == null || !context.mounted) return;

    if (action == 'delete') {
      final messenger = ScaffoldMessenger.of(context);
      final repository = ref.read(shoppingListRepositoryProvider);
      final deleted = await repository.deleteProductWithUndo(product.id);

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.itemRemoved(product.name)),
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () => repository.undoDelete(deleted),
          ),
        ),
      );
    } else {
      context.push(
        '/ingredient-recipes',
        extra: (product: product, mealName: meal.name),
      );
    }
  }
}

/// The attached recipe, with the thumbnail it has been storing all along.
///
/// `Recipes.thumbnailUrl` is populated whenever a recipe is attached from a
/// search result, and until now nothing rendered it — the recipe showed as a
/// list row with a play icon.
class _RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final String listId;
  final String mealId;

  const _RecipeCard({
    required this.recipe,
    required this.listId,
    required this.mealId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final isVideo = recipe.sourceType == RecipeSourceType.video;

    return AppCard(
      padding: const EdgeInsets.all(Insets.md),
      tint: palette.ink,
      shadowOpacity: 0.07,
      onTap: () => context.push('/recipe', extra: recipe),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: recipe.thumbnailUrl, isVideo: isVideo),
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      isVideo
                          ? context.l10n.recipeSourceVideo
                          : context.l10n.recipeSourceWeb,
                      style: AppText.caption.copyWith(color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              // Videos carry no structured ingredient data, so the importer
              // has nothing to read on them.
              if (!isVideo)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => importIngredients(
                      context,
                      ref,
                      recipeUrl: recipe.sourceUrl,
                      listId: listId,
                      mealId: mealId,
                    ),
                    icon: const FaIcon(FontAwesomeIcons.fileImport, size: 14),
                    label: Text(context.l10n.recipeImport),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    context.l10n.recipeVideoNoImport,
                    style: AppText.caption.copyWith(color: palette.inkFaint),
                  ),
                ),
              const SizedBox(width: Insets.sm),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.trashCan, size: 15),
                tooltip: context.l10n.recipeRemoveTooltip,
                onPressed: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: context.l10n.recipeRemoveTitle,
                    message: context.l10n.recipeRemoveMessage,
                    confirmLabel: context.l10n.actionRemove,
                    destructive: true,
                  );
                  if (confirmed) {
                    await ref
                        .read(recipeRepositoryProvider)
                        .deleteRecipe(recipe.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  final bool isVideo;

  const _Thumbnail({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final fallback = Container(
      width: 96,
      height: 72,
      color: palette.sunken,
      alignment: Alignment.center,
      child: FaIcon(
        isVideo ? FontAwesomeIcons.play : FontAwesomeIcons.fileLines,
        size: 18,
        color: palette.inkFaint,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.chip),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: 96,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

/// Recipes borrow the pantry hue: warm, and distinct from the green the
/// ingredient list already uses.
const _recipeSectionHue = ProductCategory.pantry;

final _mealProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  mealId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchProductsForMeal(mealId);
});

final _mealRecipesProvider = StreamProvider.family<List<Recipe>, String>((
  ref,
  mealId,
) {
  return ref.watch(recipeRepositoryProvider).watchRecipesForMeal(mealId);
});
