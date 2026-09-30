import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../core/money.dart';
import '../products/item_composer.dart';
import '../plan/plan_screen.dart' show markMealCooked;
import '../products/item_sheet.dart';
import '../sharing/share_actions.dart';
import '../sharing/changed_by.dart';

class ListDetailScreen extends ConsumerWidget {
  final ShoppingList list;

  const ListDetailScreen({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final mealsAsync = ref.watch(_mealsProvider(list.id));
    final unassignedAsync = ref.watch(_unassignedProductsProvider(list.id));
    final ticked = (unassignedAsync.valueOrNull ?? const <Product>[])
        .where((p) => p.isChecked)
        .length;

    final shared =
        ref.watch(sharedListsProvider).valueOrNull?.containsKey(list.id) ??
        false;
    // The name from the database rather than the one pushed with the route,
    // so a rename — here or by someone the list is shared with — shows.
    final name =
        ref.watch(_listProvider(list.id)).valueOrNull?.name ?? list.name;

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
              if (shared) ...[
                const SizedBox(width: Insets.sm),
                Tooltip(
                  message: l10n.listShared,
                  child: FaIcon(
                    FontAwesomeIcons.userGroup,
                    size: 14,
                    color: palette.accent,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 17),
              tooltip: l10n.shareList,
              onPressed: () => showShareActions(context, ref, list),
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.star, size: 16),
              tooltip: l10n.staplesRestock,
              onPressed: () => _restock(context, ref),
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.utensils, size: 17),
              tooltip: l10n.mealNewTitle,
              onPressed: () => _createMeal(context, ref),
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.cartShopping, size: 18),
              tooltip: l10n.listDetailShoppingMode,
              onPressed: () =>
                  context.push('/list/${list.id}/shop', extra: list),
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
                  mealsAsync.when(
                    loading: () => const SkeletonRows(count: 2),
                    error: (_, __) => ErrorState(
                      title: l10n.listDetailMealsError,
                      onRetry: () => ref.invalidate(_mealsProvider(list.id)),
                    ),
                    data: (meals) {
                      if (meals.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          for (final meal in meals) ...[
                            _MealCard(list: list, meal: meal),
                            const SizedBox(height: Insets.md),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: Insets.sm),
                  SectionLabel(
                    icon: FontAwesomeIcons.basketShopping,
                    label: l10n.listDetailOtherItems,
                    color: palette.inkMuted,
                    // Appears with the first tick and goes with the last, so
                    // it arrives rather than popping: a short fade, scaled
                    // from just under full size toward the edge it sits on.
                    trailing: AnimatedSwitcher(
                      duration: Motion.fast,
                      // Out of the way quicker than it came.
                      reverseDuration: Motion.fast ~/ 2,
                      switchInCurve: Motion.enter,
                      switchOutCurve: Motion.enter,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: context.reduceMotion
                            ? child
                            : ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.95,
                                  end: 1,
                                ).animate(animation),
                                alignment: Alignment.centerRight,
                                child: child,
                              ),
                      ),
                      child: ticked == 0
                          ? const SizedBox.shrink()
                          : TextButton.icon(
                              onPressed: () => _clearTicked(context, ref),
                              icon: const FaIcon(
                                FontAwesomeIcons.broom,
                                size: 13,
                              ),
                              label: Text(l10n.listClearTicked),
                            ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  unassignedAsync.when(
                    loading: () => const SkeletonRows(count: 2),
                    error: (_, __) => ErrorState(
                      title: l10n.listDetailItemsError,
                      onRetry: () =>
                          ref.invalidate(_unassignedProductsProvider(list.id)),
                    ),
                    data: (products) {
                      if (products.isEmpty) {
                        return InlineNote(
                          message: l10n.listDetailUnassignedNote,
                        );
                      }
                      return AppCardList(
                        tint: palette.inkMuted,
                        children: [
                          for (final product in products)
                            ProductRow(
                              key: ValueKey(product.id),
                              name: product.name,
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
                              checked: product.isChecked,
                              onToggle: (value) => ref
                                  .read(shoppingListRepositoryProvider)
                                  .toggleProductChecked(product.id, value),
                              onLongPress: () => _openItemSheet(
                                context,
                                ref,
                                product,
                                mealsAsync.valueOrNull ?? const [],
                              ),
                              trailing: IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.ellipsisVertical,
                                  size: 16,
                                ),
                                tooltip: l10n.itemActions,
                                onPressed: () => _openItemSheet(
                                  context,
                                  ref,
                                  product,
                                  mealsAsync.valueOrNull ?? const [],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            ItemComposer(
              listId: list.id,
              hintText: l10n.listDetailComposerHint,
            ),
          ],
        ),
      ),
    );
  }

  /// The shared item sheet, plus the three actions that only make sense from
  /// a list: finding a recipe, moving into a meal, and deleting.
  void _openItemSheet(
    BuildContext context,
    WidgetRef ref,
    Product product,
    List<Meal> meals,
  ) {
    showItemSheet(
      context,
      ref,
      product,
      onFindRecipes: () => context.push(
        '/ingredient-recipes',
        extra: (product: product, mealName: null),
      ),
      onMoveToMeal: () => _moveToMeal(context, ref, product, meals),
      onDelete: () => _deleteItemWithUndo(context, ref, product),
    );
  }

  /// Takes what has been bought off the list, with an undo.
  ///
  /// No confirmation first: the undo covers a mis-tap, and a dialog in front
  /// of something done after every shop would soon be dismissed unread.
  Future<void> _clearTicked(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(shoppingListRepositoryProvider);

    final cleared = await repository.clearChecked(list.id);
    if (cleared.isEmpty) return;

    messenger.replaceSnackBar(
      SnackBar(
        content: Text(l10n.listClearedTicked(cleared.length)),
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () => repository.restoreCleared(cleared),
        ),
      ),
    );
  }

  /// Adds every staple that is not already on the list.
  Future<void> _restock(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(shoppingListRepositoryProvider);
    final staples = await repository.watchStaples(userId).first;

    if (staples.isEmpty) {
      messenger.replaceSnackBar(SnackBar(content: Text(l10n.staplesNone)));
      return;
    }

    final added = await repository.restockStaples(
      listId: list.id,
      userId: userId,
    );

    messenger.replaceSnackBar(
      SnackBar(
        content: Text(
          added == 0 ? l10n.staplesAllPresent : l10n.staplesAdded(added),
        ),
      ),
    );
  }

  Future<void> _createMeal(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: context.l10n.mealNewTitle,
      hint: context.l10n.mealNewHint,
      confirmLabel: context.l10n.actionCreate,
    );
    if (name == null) return;

    await ref.read(shoppingListRepositoryProvider).createMeal(list.id, name);
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

  Future<void> _moveToMeal(
    BuildContext context,
    WidgetRef ref,
    Product product,
    List<Meal> meals,
  ) async {
    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).replaceSnackBar(
        SnackBar(content: Text(context.l10n.itemMoveNeedsMeal)),
      );
      return;
    }

    final mealId = await showAppSheet<String>(
      context: context,
      title: context.l10n.itemMoveTitle(product.name),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final meal in meals)
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.utensils, size: 17),
              title: Text(meal.name),
              onTap: () => Navigator.pop(context, meal.id),
            ),
        ],
      ),
    );

    if (mealId == null) return;

    await ref
        .read(shoppingListRepositoryProvider)
        .moveProductToMeal(product.id, mealId);
  }
}

class _MealCard extends ConsumerWidget {
  final ShoppingList list;
  final Meal meal;

  const _MealCard({required this.list, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final products =
        ref.watch(_mealProductsProvider(meal.id)).valueOrNull ?? const [];
    final checked = products.where((p) => p.isChecked).length;

    return AppCard(
      padding: const EdgeInsets.all(Insets.lg),
      shadowOpacity: 0.07,
      onTap: () =>
          context.push('/list/${list.id}/meal/${meal.id}', extra: meal),
      onLongPress: () => _mealActions(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Insets.sm),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(
                    alpha: palette.isDark ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: FaIcon(
                  FontAwesomeIcons.utensils,
                  size: 15,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  meal.name,
                  style: AppText.title.copyWith(color: palette.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (products.isNotEmpty)
                CountPill(label: '$checked/${products.length}'),
              const SizedBox(width: Insets.xs),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 13,
                color: palette.inkFaint,
              ),
            ],
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            AppProgressBar(done: checked, total: products.length, height: 6),
          ] else ...[
            const SizedBox(height: Insets.sm),
            Text(
              context.l10n.mealCardNoIngredients,
              style: AppText.caption.copyWith(color: palette.inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Rename or delete, in a sheet — a long-press with only one outcome is
  /// hard to discover and easy to trigger by accident.
  Future<void> _mealActions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final action = await showAppSheet<String>(
      context: context,
      title: meal.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.circleCheck, size: 16),
            title: Text(l10n.mealMarkCooked),
            onTap: () => Navigator.pop(context, 'cooked'),
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.pen, size: 16),
            title: Text(l10n.actionRename),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: FaIcon(
              FontAwesomeIcons.trashCan,
              size: 17,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.mealDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );

    if (action == null || !context.mounted) return;

    if (action == 'cooked') {
      await markMealCooked(context, ref, meal);
      return;
    }

    if (action == 'rename') {
      final name = await promptForText(
        context,
        title: l10n.mealRenameTitle,
        initialValue: meal.name,
      );
      if (name == null) return;
      await ref.read(shoppingListRepositoryProvider).renameMeal(meal.id, name);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(shoppingListRepositoryProvider);
    final deleted = await repository.deleteMealWithUndo(meal.id);

    messenger.replaceSnackBar(
      SnackBar(
        content: Text(l10n.mealDeleted(meal.name)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () => repository.undoDelete(deleted),
        ),
      ),
    );
  }
}

final _listProvider = StreamProvider.family<ShoppingList?, String>((
  ref,
  listId,
) {
  return ref.watch(databaseProvider).watchList(listId);
});

final _mealsProvider = StreamProvider.family<List<Meal>, String>((ref, listId) {
  return ref.watch(shoppingListRepositoryProvider).watchMeals(listId);
});

final _mealProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  mealId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchProductsForMeal(mealId);
});

final _unassignedProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, listId) {
      return ref
          .watch(shoppingListRepositoryProvider)
          .watchUnassignedProducts(listId);
    });
