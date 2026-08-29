import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../products/add_product_dialog.dart';
import '../recipes/import_ingredients_sheet.dart';

class MealDetailScreen extends ConsumerWidget {
  final String listId;
  final Meal meal;

  const MealDetailScreen({super.key, required this.listId, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_mealProductsProvider(meal.id));
    final recipesAsync = ref.watch(_mealRecipesProvider(meal.id));

    return Scaffold(
      appBar: AppBar(title: Text(meal.name)),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          productsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Error: $e'),
            data: (products) {
              if (products.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No ingredients yet.'),
                );
              }
              return Column(
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
                          icon: const FaIcon(
                            FontAwesomeIcons.ellipsisVertical,
                            size: 16,
                          ),
                          onSelected: (value) {
                            if (value == 'delete') {
                              ref
                                  .read(shoppingListRepositoryProvider)
                                  .deleteProduct(p.id);
                            } else {
                              context.push(
                                '/ingredient-recipes',
                                extra: (product: p, mealName: meal.name),
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'recipes',
                              child: Text('Find recipes…'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text('Recipe', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          recipesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Error: $e'),
            data: (recipes) {
              if (recipes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No recipe attached yet.'),
                );
              }
              return Column(
                children: recipes
                    .map(
                      (r) => Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: Icon(
                            r.sourceType == RecipeSourceType.video
                                ? FontAwesomeIcons.play
                                : FontAwesomeIcons.fileLines,
                          ),
                          title: Text(r.title),
                          subtitle: Text(
                            r.sourceType == RecipeSourceType.video
                                ? 'YouTube'
                                : 'Web',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.fileImport,
                                  size: 16,
                                ),
                                tooltip: 'Import ingredients',
                                onPressed: () => importIngredients(
                                  context,
                                  ref,
                                  recipeUrl: r.sourceUrl,
                                  listId: listId,
                                  mealId: meal.id,
                                ),
                              ),
                              IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.trashCan,
                                  size: 16,
                                ),
                                onPressed: () => ref
                                    .read(recipeRepositoryProvider)
                                    .deleteRecipe(r.id),
                              ),
                            ],
                          ),
                          onTap: () =>
                              context.push('/recipe', extra: r),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'find-recipe',
            onPressed: () => context.push(
              '/list/$listId/meal/${meal.id}/search',
              extra: meal,
            ),
            icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16),
            label: const Text('Find recipe'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add-ingredient',
            onPressed: () async {
              final result = await showAddProductDialog(context);
              if (result != null) {
                await ref
                    .read(shoppingListRepositoryProvider)
                    .addProduct(
                      listId: listId,
                      mealId: meal.id,
                      name: result.name,
                      quantity: result.quantity,
                      unit: result.unit,
                    );
              }
            },
            icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
            label: const Text('Ingredient'),
          ),
        ],
      ),
    );
  }
}

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
