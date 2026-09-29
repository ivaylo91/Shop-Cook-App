import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/repositories/recipe_repository.dart';
import '../../data/repositories/shopping_list_repository.dart';
import '../pantry/pantry_match.dart';
import '../recipes/ingredient_parser.dart';

/// One thing the week's meals still need.
class WeekItem {
  final Meal meal;
  final String name;
  final String quantity;
  final String unit;

  /// Read from the meal's saved recipe, because the meal has no ingredients
  /// of its own yet.
  final bool fromRecipe;

  /// Matches something the user has at home: offered, but not ticked.
  final bool atHome;

  const WeekItem({
    required this.meal,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.fromRecipe,
    required this.atHome,
  });
}

/// What the planned [meals] still need, to go onto the list [targetListId].
///
/// A meal on another list contributes its unticked ingredients, which then
/// go onto the target as loose items. A meal already on the target has its
/// ingredients there, and contributes nothing — unless it has none at all,
/// in which case both kinds of meal fall back to the ingredients of their
/// saved recipe ([recipeLines]), which the meal then keeps.
List<WeekItem> gatherWeek({
  required List<Meal> meals,
  required Map<String, List<Product>> ingredients,
  required Map<String, List<String>> recipeLines,
  required String targetListId,
  required Iterable<String> pantry,
}) {
  final items = <WeekItem>[];
  for (final meal in meals) {
    if (meal.cookedAt != null) continue;
    final own = ingredients[meal.id] ?? const [];

    if (own.isNotEmpty) {
      if (meal.listId == targetListId) continue;
      for (final product in own.where((p) => !p.isChecked)) {
        items.add(
          WeekItem(
            meal: meal,
            name: product.name,
            quantity: product.quantity,
            unit: product.unit,
            fromRecipe: false,
            atHome: isAtHome(product.name, pantry),
          ),
        );
      }
      continue;
    }

    for (final line in recipeLines[meal.id] ?? const <String>[]) {
      final parsed = parseIngredient(line);
      if (parsed.name.isEmpty) continue;
      items.add(
        WeekItem(
          meal: meal,
          name: parsed.name,
          quantity: parsed.quantity,
          unit: parsed.unit,
          fromRecipe: true,
          atHome: isAtHome(parsed.name, pantry),
        ),
      );
    }
  }
  return items;
}

/// Plan → "Shop for the week": everything the next seven days of meals
/// still need, onto one list, after the user has seen and trimmed it.
Future<void> shopForTheWeek(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  final db = ref.read(databaseProvider);
  final repository = ref.read(shoppingListRepositoryProvider);
  final meals = [
    for (final meal
        in await repository.watchPlannedMeals(userId, DateTime.now()).first)
      if (meal.cookedAt == null) meal,
  ];
  if (meals.isEmpty) {
    messenger.replaceSnackBar(
      SnackBar(content: Text(l10n.planShopWeekNothing)),
    );
    return;
  }

  final lists = await repository.watchLists(userId).first;
  if (!context.mounted || lists.isEmpty) return;

  // The list most of the week's meals are on comes first: usually the one.
  final onList = <String, int>{};
  for (final meal in meals) {
    onList[meal.listId] = (onList[meal.listId] ?? 0) + 1;
  }
  final ordered = [...lists]
    ..sort((a, b) => (onList[b.id] ?? 0).compareTo(onList[a.id] ?? 0));

  final target = await showAppSheet<ShoppingList>(
    context: context,
    title: l10n.planShopWeek,
    subtitle: l10n.planShopWeekPick,
    builder: (context) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final list in ordered)
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.rectangleList, size: 16),
              title: Text(list.name),
              onTap: () => Navigator.pop(context, list),
            ),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) return;

  final ingredients = {
    for (final meal in meals)
      meal.id: await db.watchProductsForMeal(meal.id).first,
  };
  final recipeLines = <String, List<String>>{};
  for (final meal in meals) {
    if (ingredients[meal.id]!.isNotEmpty) continue;
    recipeLines[meal.id] = [
      for (final recipe in await db.watchRecipesForMeal(meal.id).first)
        ...?RecipeRepository.decodeDetails(recipe.details)?.ingredients,
    ];
  }
  final pantry = [
    for (final item in await db.watchPantry(userId).first) item.key,
  ];

  final items = gatherWeek(
    meals: meals,
    ingredients: ingredients,
    recipeLines: recipeLines,
    targetListId: target.id,
    pantry: pantry,
  );
  if (!context.mounted) return;
  if (items.isEmpty) {
    messenger.replaceSnackBar(
      SnackBar(content: Text(l10n.planShopWeekAllThere(target.name))),
    );
    return;
  }

  final chosen = await showModalBottomSheet<List<WeekItem>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _WeekPicker(items: items),
  );
  if (chosen == null || chosen.isEmpty) return;

  await _add(repository, chosen, target: target, userId: userId);
  messenger.replaceSnackBar(
    SnackBar(
      content: Text(l10n.planShopWeekAdded(chosen.length, target.name)),
      action: SnackBarAction(
        label: l10n.shareOpenList,
        onPressed: () => router.push('/list/${target.id}', extra: target),
      ),
    ),
  );
}

Future<void> _add(
  ShoppingListRepository repository,
  List<WeekItem> chosen, {
  required ShoppingList target,
  required String userId,
}) async {
  for (final item in chosen) {
    // A recipe's ingredients for a meal on this list become the meal's own;
    // everything else goes on loose, merging with what is already there.
    final ownMeal = item.fromRecipe && item.meal.listId == target.id;
    await repository.addOrMergeProduct(
      listId: target.id,
      mealId: ownMeal ? item.meal.id : null,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      userId: userId,
    );
  }
}

/// The week's needs, grouped by meal, each untickable before adding.
class _WeekPicker extends StatefulWidget {
  final List<WeekItem> items;

  const _WeekPicker({required this.items});

  @override
  State<_WeekPicker> createState() => _WeekPickerState();
}

class _WeekPickerState extends State<_WeekPicker> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.items.length; i++)
      if (!widget.items[i].atHome) i,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final items = widget.items;

    final rows = <Widget>[];
    String? mealId;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.meal.id != mealId) {
        mealId = item.meal.id;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.lg,
              Insets.md,
              Insets.xs,
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.utensils,
                  size: 13,
                  color: palette.accent,
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  item.meal.name,
                  style: AppText.caption.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final detail = [
        '${item.quantity} ${item.unit}'.trim(),
        if (item.fromRecipe) l10n.planShopWeekFromRecipe,
        if (item.atHome) l10n.pantryTitle,
      ].where((part) => part.isNotEmpty).join(' · ');
      rows.add(
        CheckboxListTile(
          value: _selected.contains(i),
          onChanged: (value) => setState(
            () => (value ?? false) ? _selected.add(i) : _selected.remove(i),
          ),
          title: Text(
            item.name,
            style: AppText.body.copyWith(color: palette.ink),
          ),
          subtitle: detail.isEmpty
              ? null
              : Text(
                  detail,
                  style: AppText.caption.copyWith(color: palette.inkMuted),
                ),
          dense: true,
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        children: [
          AppSheetHeader(
            title: l10n.planShopWeekTitle,
            subtitle: l10n.importPick,
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              children: rows,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selected.length == items.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll([
                          for (var i = 0; i < items.length; i++) i,
                        ]);
                      }
                    }),
                    child: Text(
                      _selected.length == items.length
                          ? l10n.importClearAll
                          : l10n.importSelectAll,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, [
                            for (final i in _selected.toList()..sort())
                              items[i],
                          ]),
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                    label: Text(l10n.importAddCount(_selected.length)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
