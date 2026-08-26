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
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(shoppingListRepositoryProvider)
                            .deleteProduct(p.id),
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
}

class _MealTile extends ConsumerWidget {
  final ShoppingList list;
  final Meal meal;

  const _MealTile({required this.list, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.restaurant_menu),
        title: Text(meal.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(
          '/list/${list.id}/meal/${meal.id}',
          extra: meal,
        ),
      ),
    );
  }
}

final _mealsProvider = StreamProvider.family<List<Meal>, String>((ref, listId) {
  return ref.watch(shoppingListRepositoryProvider).watchMeals(listId);
});

final _unassignedProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, listId) {
      return ref
          .watch(shoppingListRepositoryProvider)
          .watchUnassignedProducts(listId);
    });
