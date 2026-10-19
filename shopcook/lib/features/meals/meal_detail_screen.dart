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
import '../../core/money.dart';
import '../products/item_composer.dart';
import '../products/item_sheet.dart';
import '../recipes/import_ingredients_sheet.dart';
import '../recipes/recipe_thumbnail.dart';
import '../shopping/product_category.dart';
import '../sharing/changed_by.dart';

class MealDetailScreen extends ConsumerWidget {
  final String listId;
  final Meal meal;

  const MealDetailScreen({super.key, required this.listId, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // The live row rather than the snapshot the route was handed, so a
    // day planned from here shows on the badge straight away.
    final meal =
        ref
            .watch(_mealsOfListProvider(listId))
            .valueOrNull
            ?.where((m) => m.id == this.meal.id)
            .firstOrNull ??
        this.meal;
    final productsAsync = ref.watch(_mealProductsProvider(meal.id));
    final recipesAsync = ref.watch(_mealRecipesProvider(meal.id));

    final recipes = recipesAsync.valueOrNull ?? const <Recipe>[];
    final first = recipes.firstOrNull;
    final products = productsAsync.valueOrNull;

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ScreenHeader(
          title: l10n.mealScreenTitle,
          back: true,
          trailing: [
            RoundIconButton(
              icon: FontAwesomeIcons.magnifyingGlass,
              tooltip: l10n.mealFindRecipe,
              onPressed: () => context.push(
                '/list/$listId/meal/${meal.id}/search',
                extra: meal,
              ),
            ),
            RoundIconButton(
              icon: meal.plannedFor == null
                  ? FontAwesomeIcons.calendarPlus
                  : FontAwesomeIcons.calendarCheck,
              tooltip: meal.plannedFor == null
                  ? l10n.mealPlanDay
                  : l10n.mealPlannedFor(
                      DateFormat('EEE d MMM', locale).format(meal.plannedFor!),
                    ),
              onPressed: () => _plan(context, ref, meal),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.sm,
                  Insets.lg,
                  Insets.xl,
                ),
                children: [
                  _MealPicture(recipe: first),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: AppText.title.copyWith(
                                fontSize: 22,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: Insets.xs),
                            Row(
                              children: [
                                if (first != null) ...[
                                  FaIcon(
                                    first.sourceType == RecipeSourceType.video
                                        ? FontAwesomeIcons.youtube
                                        : FontAwesomeIcons.globe,
                                    size: 12,
                                    color:
                                        first.sourceType ==
                                            RecipeSourceType.video
                                        ? const Color(0xFFD93025)
                                        : palette.inkMuted,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    [
                                      if (first != null)
                                        first.sourceType ==
                                                RecipeSourceType.video
                                            ? l10n.recipeSourceVideo
                                            : l10n.recipeSourceWeb,
                                      if (products != null &&
                                          products.isNotEmpty)
                                        l10n.mealIngredientCount(
                                          products.length,
                                        ),
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption.copyWith(
                                      color: palette.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (meal.plannedFor != null) ...[
                        const SizedBox(width: Insets.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(
                              alpha: palette.isDark ? 0.22 : 0.14,
                            ),
                            borderRadius: BorderRadius.circular(Radii.chip),
                          ),
                          child: Text(
                            l10n.mealPlannedBadge(
                              DateFormat(
                                'EEEE',
                                locale,
                              ).format(meal.plannedFor!),
                            ),
                            style: AppText.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: palette.heroInk,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (first != null) ...[
                    const SizedBox(height: 14),
                    // The one thing this page is for, once a recipe is on
                    // it: its ingredients onto the list.
                    PressScale(
                      child: FilledButton.icon(
                        onPressed: () => importIngredients(
                          context,
                          ref,
                          recipeUrl: first.sourceUrl,
                          listId: listId,
                          mealId: meal.id,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          elevation: 0,
                          shadowColor: palette.accent.withValues(alpha: 0.3),
                        ),
                        icon: const FaIcon(
                          FontAwesomeIcons.fileImport,
                          size: 15,
                        ),
                        label: Text(
                          l10n.recipeImport,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            l10n.mealIngredients,
                            style: AppText.title.copyWith(
                              fontWeight: FontWeight.w800,
                              color: palette.ink,
                            ),
                          ),
                        ),
                      ),
                      // A recipe on paper: the cookbook on the shelf, a card
                      // from grandma.
                      if (photoImportEnabled)
                        TextButton.icon(
                          onPressed: () => importIngredientsFromPhoto(
                            context,
                            ref,
                            listId: listId,
                            mealId: meal.id,
                          ),
                          icon: const FaIcon(FontAwesomeIcons.camera, size: 13),
                          label: Text(l10n.mealFromPhoto),
                        )
                      else if (products != null && products.isNotEmpty)
                        Text(
                          l10n.mealTickWhatYouHave,
                          style: AppText.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  productsAsync.when(
                    loading: () => const SkeletonRows(count: 3),
                    error: (_, __) => ErrorState(
                      title: l10n.mealIngredientsError,
                      onRetry: () =>
                          ref.invalidate(_mealProductsProvider(meal.id)),
                    ),
                    data: (products) {
                      if (products.isEmpty) {
                        return InlineNote(message: l10n.mealIngredientsEmpty);
                      }
                      return Column(
                        children: [
                          for (final product in products) ...[
                            _IngredientCard(
                              key: ValueKey(product.id),
                              product: product,
                              details: [
                                '${product.quantity} ${product.unit}'.trim(),
                                if (product.price != null)
                                  context.money(product.price!),
                                ?changedByLabel(
                                  context,
                                  product,
                                  names:
                                      ref
                                          .watch(
                                            memberNamesProvider(product.listId),
                                          )
                                          .valueOrNull ??
                                      const {},
                                  me: ref.watch(currentUserIdProvider),
                                ),
                              ].where((part) => part.isNotEmpty).join(' · '),
                              onToggle: (value) => ref
                                  .read(shoppingListRepositoryProvider)
                                  .toggleProductChecked(product.id, value),
                              onOpen: () =>
                                  _openItemSheet(context, ref, product),
                            ),
                            const SizedBox(height: Insets.sm),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: Insets.lg),
                  SectionLabel(
                    icon: FontAwesomeIcons.bookOpen,
                    label: l10n.mealRecipe,
                    color: palette.aisle(_recipeSectionHue),
                    trailing: TextButton.icon(
                      onPressed: () => _addFromLibrary(context, ref, recipes),
                      icon: const FaIcon(FontAwesomeIcons.bookOpen, size: 13),
                      label: Text(l10n.mealFromLibrary),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  recipesAsync.when(
                    loading: () => const SkeletonRows(count: 1),
                    error: (_, __) => ErrorState(
                      title: l10n.mealRecipeError,
                      onRetry: () =>
                          ref.invalidate(_mealRecipesProvider(meal.id)),
                    ),
                    data: (recipes) {
                      if (recipes.isEmpty) {
                        return InlineNote(message: l10n.mealRecipeEmpty);
                      }
                      return Column(
                        children: [
                          for (final (i, recipe) in recipes.indexed) ...[
                            _RecipeCard(
                              recipe: recipe,
                              listId: listId,
                              mealId: meal.id,
                              // The first one's import is the big button
                              // at the top of the page.
                              showImport: i > 0,
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
      ),
    );
  }

  /// Puts an already-saved recipe on this meal.
  Future<void> _addFromLibrary(
    BuildContext context,
    WidgetRef ref,
    List<Recipe> onMeal,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(recipeRepositoryProvider);
    final attached = {for (final r in onMeal) r.id};
    final candidates = [
      for (final entry in await repository.watchLibrary(userId).first)
        if (!attached.contains(entry.recipe.id)) entry.recipe,
    ];
    if (!context.mounted) return;

    if (candidates.isEmpty) {
      messenger.replaceSnackBar(
        SnackBar(content: Text(l10n.mealFromLibraryNone)),
      );
      return;
    }

    final picked = await showAppSheet<Recipe>(
      context: context,
      title: l10n.mealFromLibrary,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final recipe in candidates)
              ListTile(
                leading: RecipeThumbnail(
                  url: recipe.thumbnailUrl,
                  isVideo: recipe.sourceType == RecipeSourceType.video,
                  width: 56,
                  height: 42,
                ),
                title: Text(
                  recipe.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, recipe),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;

    await repository.linkToMeal(mealId: meal.id, recipeId: picked.id);
  }

  /// Gives the meal a day, or takes it off the plan.
  ///
  /// Takes the live [meal], so moving or clearing starts from the day it
  /// has now rather than the one it had when the screen opened.
  Future<void> _plan(BuildContext context, WidgetRef ref, Meal meal) async {
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

  /// The shared item sheet. From a meal there is no other meal to move to,
  /// so only recipes and delete are offered alongside the item-level actions.
  void _openItemSheet(BuildContext context, WidgetRef ref, Product product) {
    showItemSheet(
      context,
      ref,
      product,
      onFindRecipes: () => context.push(
        '/ingredient-recipes',
        extra: (
          name: product.name,
          mealId: product.mealId,
          mealName: meal.name,
        ),
      ),
      onDelete: () => _deleteItemWithUndo(context, ref, product),
    );
  }

  Future<void> _deleteItemWithUndo(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(shoppingListRepositoryProvider);
    final deleted = await repository.deleteProductWithUndo(product.id);

    messenger.replaceSnackBar(
      SnackBar(
        content: Text(l10n.itemRemoved(product.name)),
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () => repository.undoDelete(deleted),
        ),
      ),
    );
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
  final bool showImport;

  const _RecipeCard({
    required this.recipe,
    required this.listId,
    required this.mealId,
    this.showImport = true,
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
          if (showImport) ...[
          const SizedBox(height: Insets.md),
          // Import gets a row of its own: "Внеси съставките" does not fit
          // in half a card beside a second button, and wrapped badly.
          // A video's ingredients come from its description, or from the
          // recipe page it links to; see the import-recipe function.
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => importIngredients(
                context,
                ref,
                recipeUrl: recipe.sourceUrl,
                listId: listId,
                mealId: mealId,
              ),
              icon: const FaIcon(FontAwesomeIcons.fileImport, size: 14),
              label: Text(
                context.l10n.recipeImport,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ],
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/cook', extra: recipe),
                  icon: const FaIcon(FontAwesomeIcons.kitchenSet, size: 14),
                  label: Text(context.l10n.cookModeStart),
                ),
              ),
              const SizedBox(width: Insets.sm),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.trashCan, size: 15),
                tooltip: context.l10n.recipeRemoveTooltip,
                onPressed: () async {
                  final l10n = context.l10n;
                  final messenger = ScaffoldMessenger.of(context);
                  // Taking it off the meal, not deleting it: the recipe
                  // stays in the library for the next time.
                  final confirmed = await confirmAction(
                    context,
                    title: l10n.recipeDetachTitle,
                    message: l10n.recipeDetachMessage,
                    confirmLabel: l10n.actionRemove,
                  );
                  if (!confirmed) return;
                  await ref
                      .read(recipeRepositoryProvider)
                      .detachFromMeal(mealId: mealId, recipeId: recipe.id);
                  messenger.replaceSnackBar(
                    SnackBar(content: Text(l10n.recipeDetached)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The meal's picture: the recipe's own, on a soft white glow, or the
/// cooking picture while there is no recipe with one.
class _MealPicture extends StatelessWidget {
  final Recipe? recipe;

  const _MealPicture({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final recipe = this.recipe;
    final hasPhoto = recipe != null && recipe.thumbnailUrl.isNotEmpty;

    return Container(
      height: 170,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: RadialGradient(
          center: const Alignment(0, 0.1),
          colors: [
            const Color(0xFFFFFFFF).withValues(
              alpha: context.palette.isDark ? 0.06 : 1,
            ),
            const Color(0xFFFFFFFF).withValues(
              alpha: context.palette.isDark ? 0.02 : 0.4,
            ),
            const Color(0x00FFFFFF),
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: hasPhoto
          ? RecipeThumbnail(
              url: recipe.thumbnailUrl,
              isVideo: recipe.sourceType == RecipeSourceType.video,
              width: 250,
              height: 150,
              radius: Radii.card,
            )
          : const Illustration(Art.cooking, size: 160),
    );
  }
}

/// One ingredient as a card of its own: its aisle's picture, name and
/// amount, and a round tick for "got it".
class _IngredientCard extends StatelessWidget {
  final Product product;
  final String details;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  const _IngredientCard({
    super.key,
    required this.product,
    required this.details,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final aisle = ShoppingListRepository.aisleOf(product);
    final checked = product.isChecked;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, 6, Insets.sm),
      shadowOpacity: 0.07,
      onTap: onOpen,
      onLongPress: onOpen,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: palette.aisleTile(aisle),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Illustration(Art.of(aisle), size: 42),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: checked ? palette.inkMuted : palette.ink,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: palette.inkMuted,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          Semantics(
            checked: checked,
            label: product.name,
            excludeSemantics: true,
            child: InkResponse(
              onTap: () => onToggle(!checked),
              radius: 24,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    curve: Motion.enter,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: checked ? palette.accent : Colors.transparent,
                      border: checked
                          ? null
                          : Border.all(color: palette.inkFaint, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: checked
                        ? FaIcon(
                            FontAwesomeIcons.check,
                            size: 12,
                            color: palette.onAccent,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
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

final _mealsOfListProvider = StreamProvider.family<List<Meal>, String>((
  ref,
  listId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchMeals(listId);
});

final _mealRecipesProvider = StreamProvider.family<List<Recipe>, String>((
  ref,
  mealId,
) {
  return ref.watch(recipeRepositoryProvider).watchRecipesForMeal(mealId);
});
