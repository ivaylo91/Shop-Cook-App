import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/repositories/shopping_list_repository.dart';

/// The week ahead: which meal is cooked on which day.
///
/// The app is called ShopCook and until now it only shopped. Meals already
/// existed as a first-class thing with their own ingredients and recipe, so
/// this is mostly a second view of data that was already there — what it adds
/// is a reason to open the app on a day you are not in a supermarket.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final today = ShoppingListRepository.dayOf(DateTime.now());
    final plannedAsync = ref.watch(plannedMealsProvider);
    final unplanned = ref.watch(unplannedMealsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Plan')),
      body: plannedAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: SkeletonRows(count: 4),
        ),
        error: (_, __) => ErrorState(
          title: 'Could not load your plan',
          onRetry: () => ref.invalidate(plannedMealsProvider),
        ),
        data: (planned) {
          final byDay = <DateTime, List<Meal>>{};
          for (final meal in planned) {
            final day = ShoppingListRepository.dayOf(meal.plannedFor!);
            byDay.putIfAbsent(day, () => []).add(meal);
          }

          if (planned.isEmpty && unplanned.isEmpty) {
            return EmptyState(
              icon: FontAwesomeIcons.calendarDays,
              title: 'Nothing planned yet',
              message: 'Create a meal inside a shopping list, then give it a '
                  'day here. Its ingredients come along with it.',
              actionLabel: 'Go to your lists',
              actionIcon: FontAwesomeIcons.rectangleList,
              onAction: () => context.go('/lists'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.lg,
              Insets.lg,
              Insets.xxl,
            ),
            children: [
              for (var offset = 0; offset < 7; offset++)
                _DaySection(
                  day: DateTime(today.year, today.month, today.day + offset),
                  isToday: offset == 0,
                  meals:
                      byDay[DateTime(
                        today.year,
                        today.month,
                        today.day + offset,
                      )] ??
                      const [],
                  hasIdeas: unplanned.isNotEmpty,
                ),
              if (unplanned.isNotEmpty) ...[
                const SizedBox(height: Insets.xl),
                SectionLabel(
                  icon: FontAwesomeIcons.lightbulb,
                  label: 'Not yet planned',
                  count: unplanned.length,
                  color: palette.inkMuted,
                ),
                const SizedBox(height: Insets.md),
                AppCardList(
                  tint: palette.inkMuted,
                  dividerIndent: Insets.lg,
                  children: [
                    for (final meal in unplanned)
                      _MealRow(meal: meal, showDay: false),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One day, with whatever is cooked on it.
class _DaySection extends ConsumerWidget {
  final DateTime day;
  final bool isToday;
  final List<Meal> meals;

  /// Whether there is anything to assign; without ideas the "plan a meal"
  /// affordance would open an empty sheet.
  final bool hasIdeas;

  const _DaySection({
    required this.day,
    required this.isToday,
    required this.meals,
    required this.hasIdeas,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tint = isToday ? palette.accent : palette.inkMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('EEEE').format(day),
                style: AppText.title.copyWith(color: tint),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                DateFormat('d MMM').format(day),
                style: AppText.caption.copyWith(color: palette.inkFaint),
              ),
              if (isToday) ...[
                const SizedBox(width: Insets.sm),
                CountPill(label: 'Today'),
              ],
              const Spacer(),
              if (hasIdeas)
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  tooltip: 'Plan a meal for this day',
                  onPressed: () => _assign(context, ref),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          if (meals.isEmpty)
            Text(
              'Nothing planned',
              style: AppText.caption.copyWith(color: palette.inkFaint),
            )
          else
            AppCardList(
              tint: tint,
              dividerIndent: Insets.lg,
              children: [
                for (final meal in meals) _MealRow(meal: meal, showDay: true),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final ideas = await ref.read(shoppingListRepositoryProvider)
        .watchUnplannedMeals()
        .first;
    if (!context.mounted || ideas.isEmpty) return;

    final mealId = await showAppSheet<String>(
      context: context,
      title: 'Cook on ${DateFormat('EEEE d MMM').format(day)}',
      subtitle: 'Pick a meal that has no day yet.',
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final meal in ideas)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.utensils, size: 17),
                title: Text(meal.name),
                onTap: () => Navigator.pop(context, meal.id),
              ),
          ],
        ),
      ),
    );

    if (mealId == null) return;
    await ref.read(shoppingListRepositoryProvider).planMeal(mealId, day);
  }
}

/// A planned meal, with how far through its shopping you are.
class _MealRow extends ConsumerWidget {
  final Meal meal;
  final bool showDay;

  const _MealRow({required this.meal, required this.showDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final products =
        ref.watch(mealProductsProvider(meal.id)).valueOrNull ?? const [];
    final checked = products.where((p) => p.isChecked).length;

    final detail = products.isEmpty
        ? 'No ingredients yet'
        : '$checked of ${products.length} bought';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.xs,
      ),
      leading: FaIcon(
        FontAwesomeIcons.utensils,
        size: 16,
        color: palette.inkMuted,
      ),
      title: Text(meal.name),
      subtitle: Text(detail),
      trailing: IconButton(
        icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 15),
        tooltip: 'Meal actions',
        onPressed: () => _actions(context, ref),
      ),
      onTap: () => context.push(
        '/list/${meal.listId}/meal/${meal.id}',
        extra: meal,
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final action = await showAppSheet<String>(
      context: context,
      title: meal.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.calendarDay, size: 16),
            title: Text(showDay ? 'Move to another day' : 'Give it a day'),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
          if (showDay)
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.calendarXmark, size: 16),
              title: const Text('Take off the plan'),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
        ],
      ),
    );

    if (action == null || !context.mounted) return;
    final repository = ref.read(shoppingListRepositoryProvider);

    if (action == 'clear') {
      await repository.planMeal(meal.id, null);
      return;
    }

    final today = ShoppingListRepository.dayOf(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: meal.plannedFor ?? today,
      firstDate: DateTime(today.year, today.month, today.day - 30),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: 'Cook ${meal.name} on',
    );

    if (picked == null) return;
    await repository.planMeal(meal.id, picked);
  }
}

final plannedMealsProvider = StreamProvider<List<Meal>>((ref) {
  return ref
      .watch(shoppingListRepositoryProvider)
      .watchPlannedMeals(DateTime.now());
});

final unplannedMealsProvider = StreamProvider<List<Meal>>((ref) {
  return ref.watch(shoppingListRepositoryProvider).watchUnplannedMeals();
});

final mealProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  mealId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchProductsForMeal(mealId);
});
