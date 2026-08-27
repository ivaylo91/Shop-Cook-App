import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'product_category.dart';

/// Everything to buy across every meal in one flat, aisle-ordered checklist —
/// the view you actually want while walking around a shop.
class ShoppingModeScreen extends ConsumerWidget {
  final ShoppingList list;

  const ShoppingModeScreen({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products =
        ref.watch(_shopProductsProvider(list.id)).valueOrNull ?? const [];
    final meals = ref.watch(_shopMealsProvider(list.id)).valueOrNull ?? const [];
    final mealNames = {for (final meal in meals) meal.id: meal.name};

    final remaining = products.where((p) => !p.isChecked).toList();
    final picked = products.where((p) => p.isChecked).toList();

    return Scaffold(
      appBar: AppBar(title: Text(list.name)),
      body: products.isEmpty
          ? const Center(child: Text('Nothing to buy yet.'))
          : ListView(
              children: [
                _ProgressHeader(picked: picked.length, total: products.length),
                if (remaining.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('All done — everything is in the basket.'),
                  ),
                for (final category in ProductCategory.values)
                  ..._categorySection(context, ref, category, remaining,
                      mealNames),
                if (picked.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.shopping_basket_outlined,
                    label: 'In the basket (${picked.length})',
                  ),
                  for (final product in picked)
                    _ProductRow(
                      product: product,
                      mealNames: mealNames,
                      onToggle: (value) => ref
                          .read(shoppingListRepositoryProvider)
                          .toggleProductChecked(product.id, value),
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  /// Header plus rows for one aisle, or nothing at all when it is empty.
  List<Widget> _categorySection(
    BuildContext context,
    WidgetRef ref,
    ProductCategory category,
    List<Product> remaining,
    Map<String, String> mealNames,
  ) {
    final items = remaining.where((p) => categorize(p.name) == category);
    if (items.isEmpty) return const [];

    return [
      _SectionHeader(icon: category.icon, label: category.label),
      for (final product in items)
        _ProductRow(
          product: product,
          mealNames: mealNames,
          onToggle: (value) => ref
              .read(shoppingListRepositoryProvider)
              .toggleProductChecked(product.id, value),
        ),
    ];
  }
}

class _ProgressHeader extends StatelessWidget {
  final int picked;
  final int total;

  const _ProgressHeader({required this.picked, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$picked of $total picked up',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: total == 0 ? 0 : picked / total),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final Map<String, String> mealNames;
  final ValueChanged<bool> onToggle;

  const _ProductRow({
    required this.product,
    required this.mealNames,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Why it's on the list: how much, and which meal wants it.
    final details = [
      '${product.quantity} ${product.unit}'.trim(),
      if (product.mealId != null) mealNames[product.mealId] ?? '',
    ].where((part) => part.isNotEmpty).join(' · ');

    return CheckboxListTile(
      value: product.isChecked,
      onChanged: (value) => onToggle(value ?? false),
      title: Text(
        product.name,
        style: product.isChecked
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).disabledColor,
              )
            : null,
      ),
      subtitle: details.isEmpty ? null : Text(details),
    );
  }
}

final _shopProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  listId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchAllProducts(listId);
});

final _shopMealsProvider = StreamProvider.family<List<Meal>, String>((
  ref,
  listId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchMeals(listId);
});
