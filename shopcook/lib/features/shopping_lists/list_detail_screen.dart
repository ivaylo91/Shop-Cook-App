import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../products/add_product_dialog.dart';

class ListDetailScreen extends ConsumerWidget {
  final ShoppingList list;

  const ListDetailScreen({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(_mealsProvider(list.id));
    final unassignedAsync = ref.watch(_unassignedProductsProvider(list.id));

    return Scaffold(
      appBar: AppBar(title: Text(list.name)),
      body: ListView(
        children: [
          mealsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (meals) => Column(
              children: meals
                  .map((meal) => _MealTile(list: list, meal: meal))
                  .toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Other items',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          unassignedAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Error: $e'),
            data: (products) => Column(
              children: products
                  .map(
                    (p) => CheckboxListTile(
                      value: p.isChecked,
                      title: Text(p.name),
                      subtitle: p.quantity.isEmpty && p.unit.isEmpty
                          ? null
                          : Text('${p.quantity} ${p.unit}'.trim()),
                      onChanged: (v) => ref
                          .read(shoppingListRepositoryProvider)
                          .toggleProductChecked(p.id, v ?? false),
                      secondary: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            ref
                                .read(shoppingListRepositoryProvider)
                                .deleteProduct(p.id);
                          } else {
                            _moveToMeal(
                              context,
                              ref,
                              p,
                              mealsAsync.valueOrNull ?? const [],
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'move',
                            child: Text('Move to meal…'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add-meal',
            onPressed: () => _createMeal(context, ref),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Meal'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add-product',
            onPressed: () async {
              final result = await showAddProductDialog(context);
              if (result != null) {
                await ref
                    .read(shoppingListRepositoryProvider)
                    .addProduct(
                      listId: list.id,
                      name: result.name,
                      quantity: result.quantity,
                      unit: result.unit,
                    );
              }
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _createMeal(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New meal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Spaghetti Bolognese'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref
          .read(shoppingListRepositoryProvider)
          .createMeal(list.id, name.trim());
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

    final mealId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Move "${product.name}" to',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final meal in meals)
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: Text(meal.name),
                onTap: () => Navigator.pop(context, meal.id),
              ),
          ],
        ),
      ),
    );

    if (mealId != null) {
      await ref
          .read(shoppingListRepositoryProvider)
          .moveProductToMeal(product.id, mealId);
    }
  }
}

class _MealTile extends ConsumerWidget {
  final ShoppingList list;
  final Meal meal;

  const _MealTile({required this.list, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products =
        ref.watch(_mealProductsProvider(meal.id)).valueOrNull ?? const [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.restaurant_menu),
        title: Text(meal.name),
        subtitle: Text(_ingredientSummary(products)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete meal',
              onPressed: () => _confirmDelete(context, ref),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(
          '/list/${list.id}/meal/${meal.id}',
          extra: meal,
        ),
      ),
    );
  }

  String _ingredientSummary(List<Product> products) {
    if (products.isEmpty) return 'No ingredients yet';
    final checked = products.where((p) => p.isChecked).length;
    final noun = products.length == 1 ? 'ingredient' : 'ingredients';
    return '${products.length} $noun · $checked checked';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${meal.name}"?'),
        content: const Text(
          'Its ingredients and attached recipe will be deleted too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
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
