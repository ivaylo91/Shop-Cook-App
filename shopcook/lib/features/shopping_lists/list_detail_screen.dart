import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../products/add_product_dialog.dart';

class ListDetailScreen extends ConsumerWidget {
  final ShoppingList list;

  const ListDetailScreen({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final mealsAsync = ref.watch(_mealsProvider(list.id));
    final unassignedAsync = ref.watch(_unassignedProductsProvider(list.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.cartShopping, size: 18),
            tooltip: 'Shopping mode',
            onPressed: () => context.push('/list/${list.id}/shop', extra: list),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          // Room for the two floating actions.
          96,
        ),
        children: [
          mealsAsync.when(
            loading: () => const SkeletonRows(count: 2),
            error: (_, __) => ErrorState(
              title: 'Could not load the meals',
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
            label: 'Other items',
            color: palette.inkMuted,
          ),
          const SizedBox(height: Insets.md),
          unassignedAsync.when(
            loading: () => const SkeletonRows(count: 2),
            error: (_, __) => ErrorState(
              title: 'Could not load the items',
              onRetry: () =>
                  ref.invalidate(_unassignedProductsProvider(list.id)),
            ),
            data: (products) {
              if (products.isEmpty) {
                return const InlineNote(
                  message: 'Anything you add without picking a meal lands '
                      'here — the milk and the washing-up liquid.',
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
                        tooltip: 'Item actions',
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
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add-meal',
            onPressed: () => _createMeal(context, ref),
            icon: const FaIcon(FontAwesomeIcons.utensils, size: 16),
            label: const Text('Meal'),
          ),
          const SizedBox(width: Insets.md),
          FloatingActionButton.extended(
            heroTag: 'add-product',
            onPressed: () async {
              final result = await showAddProductDialog(context);
              if (result == null) return;
              await ref.read(shoppingListRepositoryProvider).addProduct(
                listId: list.id,
                name: result.name,
                quantity: result.quantity,
                unit: result.unit,
              );
            },
            icon: const FaIcon(FontAwesomeIcons.cartPlus, size: 16),
            label: const Text('Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _createMeal(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: 'New meal',
      hint: 'e.g. Spaghetti Bolognese',
      confirmLabel: 'Create',
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
    final action = await showAppSheet<String>(
      context: context,
      title: product.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 17),
            title: const Text('Find recipes'),
            subtitle: const Text('What can I cook with this?'),
            onTap: () => Navigator.pop(context, 'recipes'),
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.utensils, size: 17),
            title: const Text('Move to a meal'),
            onTap: () => Navigator.pop(context, 'move'),
          ),
          ListTile(
            leading: FaIcon(
              FontAwesomeIcons.trashCan,
              size: 17,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete',
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
        await ref.read(shoppingListRepositoryProvider).deleteProduct(
          product.id,
        );
      case 'move':
        await _moveToMeal(context, ref, product, meals);
    }
  }

  Future<void> _moveToMeal(
    BuildContext context,
    WidgetRef ref,
    Product product,
    List<Meal> meals,
  ) async {
    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a meal first, then move items into it.'),
        ),
      );
      return;
    }

    final mealId = await showAppSheet<String>(
      context: context,
      title: 'Move "${product.name}" to',
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
      onLongPress: () => _confirmDelete(context, ref),
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
              'No ingredients yet — open it to add some or find a recipe.',
              style: AppText.caption.copyWith(color: palette.inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete "${meal.name}"?',
      message: 'Its ingredients and attached recipe will be deleted too.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(shoppingListRepositoryProvider).deleteMeal(meal.id);
    }
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
