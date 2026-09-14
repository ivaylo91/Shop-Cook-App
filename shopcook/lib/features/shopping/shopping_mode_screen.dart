import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../products/item_composer.dart';
import 'product_category.dart';

/// Everything to buy across every meal in one flat, aisle-ordered checklist —
/// the view you actually want while walking around a shop, one-handed.
class ShoppingModeScreen extends ConsumerWidget {
  final ShoppingList list;

  const ShoppingModeScreen({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_shopProductsProvider(list.id));
    final meals = ref.watch(_shopMealsProvider(list.id)).valueOrNull ?? const [];
    final mealNames = {for (final meal in meals) meal.id: meal.name};

    return Scaffold(
      appBar: AppBar(title: Text(list.name)),
      // The composer stays reachable while shopping: remembering something
      // mid-aisle should not mean backing out of the view you are using.
      body: Column(
        children: [
          Expanded(child: _body(context, ref, productsAsync, mealNames)),
          ItemComposer(listId: list.id, hintText: 'Remembered something?'),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Product>> productsAsync,
    Map<String, String> mealNames,
  ) {
    final palette = context.palette;

    return productsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: SkeletonRows(count: 4),
        ),
        error: (_, __) => ErrorState(
          title: 'Could not load this list',
          details: 'The list is stored on this device, so this is usually '
              'temporary. Try again.',
          onRetry: () => ref.invalidate(_shopProductsProvider(list.id)),
        ),
        data: (products) {
          if (products.isEmpty) {
            return EmptyState(
              icon: FontAwesomeIcons.cartShopping,
              title: 'Nothing to buy yet',
              message: 'Add ingredients to your meals and they will show up '
                  'here, grouped by aisle so you can shop straight down the '
                  'list.',
              actionLabel: 'Add ingredients',
              onAction: () => Navigator.pop(context),
            );
          }

          final remaining = products.where((p) => !p.isChecked).toList();
          final picked = products.where((p) => p.isChecked).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.xxl,
            ),
            children: [
              _ProgressHero(picked: picked.length, total: products.length),
              if (remaining.isEmpty) ...[
                const SizedBox(height: Insets.xl),
                _DonePeak(total: products.length),
              ],
              for (final category in ProductCategory.values)
                ..._aisle(context, ref, category, remaining, mealNames),
              if (picked.isNotEmpty) ...[
                const SizedBox(height: Insets.xl),
                SectionLabel(
                  icon: FontAwesomeIcons.basketShopping,
                  label: 'In the basket',
                  count: picked.length,
                  color: palette.inkMuted,
                ),
                const SizedBox(height: Insets.md),
                // Done work should recede so the eye stays on what's left.
                Opacity(
                  opacity: 0.6,
                  child: _ItemGroup(
                    tint: palette.ink,
                    products: picked,
                    mealNames: mealNames,
                    onToggle: (product, value) => _toggle(ref, product, value),
                  ),
                ),
              ],
            ],
          );
        },
    );
  }

  /// Header plus grouped rows for one aisle, or nothing when it is empty.
  List<Widget> _aisle(
    BuildContext context,
    WidgetRef ref,
    ProductCategory category,
    List<Product> remaining,
    Map<String, String> mealNames,
  ) {
    final items = remaining
        .where((p) => categorize(p.name) == category)
        .toList();
    if (items.isEmpty) return const [];

    final tint = context.palette.aisle(category);
    return [
      const SizedBox(height: Insets.xl),
      SectionLabel(
        icon: category.icon,
        label: category.label,
        count: items.length,
        color: tint,
      ),
      const SizedBox(height: Insets.md),
      _ItemGroup(
        tint: tint,
        products: items,
        mealNames: mealNames,
        onToggle: (product, value) => _toggle(ref, product, value),
      ),
    ];
  }

  void _toggle(WidgetRef ref, Product product, bool value) {
    ref
        .read(shoppingListRepositoryProvider)
        .toggleProductChecked(product.id, value);
  }
}

/// The one number that matters, sized so it reads at arm's length.
class _ProgressHero extends StatelessWidget {
  final int picked;
  final int total;

  const _ProgressHero({required this.picked, required this.total});

  String get _encouragement {
    if (picked == 0) return 'Nothing in the basket yet';
    if (picked == total) return 'Every item accounted for';
    if (total - picked == 1) return 'One to go — almost there';
    return '${total - picked} still to find';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$picked',
                style: AppText.display.copyWith(color: palette.accent),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                'of $total picked up',
                style: AppText.body.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          AppProgressBar(done: picked, total: total),
          const SizedBox(height: Insets.md),
          Text(
            _encouragement,
            style: AppText.caption.copyWith(color: palette.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// The peak: the moment the last item goes in the basket.
class _DonePeak extends StatelessWidget {
  final int total;

  const _DonePeak({required this.total});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: Motion.slow,
      curve: Motion.emphasis,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xxl,
        ),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: palette.isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: palette.accent.withValues(alpha: palette.isDark ? 0.28 : 0.16),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: palette.accent.withValues(
                  alpha: palette.isDark ? 0.22 : 0.14,
                ),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.check,
                size: 32,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text('Shopping done', style: AppText.title.copyWith(color: palette.ink)),
            const SizedBox(height: Insets.sm),
            Text(
              total == 1
                  ? 'The one thing on your list is in the basket.'
                  : 'All $total items are in the basket. Time to cook.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rows for one aisle, grouped into a single card so the list has rhythm.
class _ItemGroup extends StatelessWidget {
  final Color tint;
  final List<Product> products;
  final Map<String, String> mealNames;
  final void Function(Product product, bool value) onToggle;

  const _ItemGroup({
    required this.tint,
    required this.products,
    required this.mealNames,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCardList(
      tint: tint,
      children: [
        for (final product in products)
          ProductRow(
            name: product.name,
            // Why it's on the list: how much, and which meal wants it.
            details: [
              '${product.quantity} ${product.unit}'.trim(),
              if (product.mealId != null) mealNames[product.mealId] ?? '',
            ].where((part) => part.isNotEmpty).join(' · '),
            checked: product.isChecked,
            onToggle: (value) => onToggle(product, value),
          ),
      ],
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
