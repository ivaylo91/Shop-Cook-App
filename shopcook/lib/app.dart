import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/localization.dart';
import 'core/providers.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'data/local/database.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/cooking/cooking_mode_screen.dart';
import 'features/meals/meal_detail_screen.dart';
import 'features/plan/plan_screen.dart';
import 'features/recipes/library_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/recipes/ingredient_recipes_screen.dart';
import 'features/recipes/recipe_search_screen.dart';
import 'features/recipes/recipe_view_screen.dart';
import 'features/shopping/shopping_mode_screen.dart';
import 'features/shopping_lists/list_detail_screen.dart';
import 'features/shopping_lists/lists_screen.dart';

const _authRoutes = {'/login', '/register'};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(auth.authStateChanges);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/lists',
    refreshListenable: refresh,
    redirect: (context, state) {
      // The session is restored from local storage at startup, so a
      // returning user is not bounced to login merely for being offline.
      final signedIn = auth.currentSession != null;
      final headingToAuth = _authRoutes.contains(state.matchedLocation);

      if (!signedIn) return headingToAuth ? null : '/login';
      if (headingToAuth) return '/lists';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // The tabs. Each branch keeps its own navigator, so switching
      // tabs does not throw away where you were.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lists',
                builder: (context, state) => const ListsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recipes',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
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
        path: '/ingredient-recipes',
        builder: (context, state) {
          final args = state.extra as ({Product product, String? mealName});
          return IngredientRecipesScreen(
            product: args.product,
            mealName: args.mealName,
          );
        },
      ),
      GoRoute(
        path: '/cook',
        builder: (context, state) =>
            CookingModeScreen(recipe: state.extra as Recipe),
      ),
      GoRoute(
        path: '/recipe',
        builder: (context, state) =>
            RecipeViewScreen(recipe: state.extra as Recipe),
      ),
    ],
  );
});

/// Bridges a stream to the Listenable go_router wants, so navigation
/// re-evaluates the moment auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class ShopCookApp extends ConsumerWidget {
  const ShopCookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      // Null follows the phone; Flutter then picks the closest supported
      // locale and falls back to the template (English) if there is none.
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: supportedAppLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
