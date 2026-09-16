import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../products/item_composer.dart';

class ListDetailScreen extends ConsumerWidget {
  final ShoppingList list;

  const ListDetailScreen({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final mealsAsync = ref.watch(_mealsProvider(list.id));
    final unassignedAsync = ref.watch(_unassignedProductsProvider(list.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.utensils, size: 17),
            tooltip: l10n.mealNewTitle,
            onPressed: () => _createMeal(context, ref),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.cartShopping, size: 18),
            tooltip: l10n.listDetailShoppingMode,
            onPressed: () => context.push('/list/${list.id}/shop', extra: list),
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
                            name: product.name,
                            details: '${product.quantity} ${product.unit}'.trim(),
                            checked: product.isChecked,
                            onToggle: (value) => ref
                                .read(shoppingListRepositoryProvider)
                                .toggleProductChecked(product.id, value),
                            onLongPress: () => _itemActions(
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
                              onPressed: () => _itemActions(
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

  /// Everything you can do to one item, in a sheet rather than a menu — it is
  /// reachable with a thumb and has room for labels that explain themselves.
  Future<void> _itemActions(
    BuildContext context,
    WidgetRef ref,
    Product product,
    List<Meal> meals,
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
            subtitle: Text(l10n.itemFindRecipesFromList),
            onTap: () => Navigator.pop(context, 'recipes'),
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.utensils, size: 17),
            title: Text(l10n.itemMoveToMeal),
            onTap: () => Navigator.pop(context, 'move'),
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

    switch (action) {
      case 'recipes':
        context.push(
          '/ingredient-recipes',
          extra: (product: product, mealName: null),
        );
      case 'delete':
        await _deleteItemWithUndo(context, ref, product);
      case 'move':
        await _moveToMeal(context, ref, product, meals);
    }
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

    messenger.showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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

    messenger.showSnackBar(
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
