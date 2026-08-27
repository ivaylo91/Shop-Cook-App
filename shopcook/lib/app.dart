import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/local/database.dart';
import 'features/meals/meal_detail_screen.dart';
import 'features/recipes/recipe_search_screen.dart';
import 'features/recipes/recipe_view_screen.dart';
import 'features/shopping/shopping_mode_screen.dart';
import 'features/shopping_lists/list_detail_screen.dart';
import 'features/shopping_lists/lists_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ListsScreen()),
    GoRoute(
      path: '/list/:listId',
      builder: (context, state) =>
          ListDetailScreen(list: state.extra as ShoppingList),
    ),
    GoRoute(
      path: '/list/:listId/shop',
      builder: (context, state) =>
          ShoppingModeScreen(list: state.extra as ShoppingList),
    ),
    GoRoute(
      path: '/list/:listId/meal/:mealId',
      builder: (context, state) => MealDetailScreen(
        listId: state.pathParameters['listId']!,
        meal: state.extra as Meal,
      ),
    ),
    GoRoute(
      path: '/list/:listId/meal/:mealId/search',
      builder: (context, state) =>
          RecipeSearchScreen(meal: state.extra as Meal),
    ),
    GoRoute(
      path: '/recipe',
      builder: (context, state) =>
          RecipeViewScreen(recipe: state.extra as Recipe),
    ),
  ],
);

class ShopCookApp extends StatelessWidget {
  const ShopCookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ShopCook',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
