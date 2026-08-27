import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'product_category.dart';

/// Everything to buy across every meal in one flat, aisle-ordered checklist —
/// the view you actually want while walking around a shop, one-handed.
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(list.name, style: AppText.title),
      ),
      body: products.isEmpty
          ? const _EmptyState()
          : ListView(
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
                  ..._aisle(ref, category, remaining, mealNames),
                if (picked.isNotEmpty) ...[
                  const SizedBox(height: Insets.xl),
                  _SectionLabel(
                    icon: FontAwesomeIcons.basketShopping,
                    label: 'In the basket',
                    count: picked.length,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(height: Insets.md),
                  // Done work should recede so the eye stays on what's left.
                  Opacity(
                    opacity: 0.6,
                    child: _ItemGroup(
                      tint: AppColors.ink,
                      products: picked,
                      mealNames: mealNames,
                      onToggle: (product, value) => _toggle(ref, product, value),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Header plus grouped rows for one aisle, or nothing when it is empty.
  List<Widget> _aisle(
    WidgetRef ref,
    ProductCategory category,
    List<Product> remaining,
    Map<String, String> mealNames,
  ) {
    final items = remaining
        .where((p) => categorize(p.name) == category)
        .toList();
    if (items.isEmpty) return const [];

    final tint = categoryColor(category);
    return [
      const SizedBox(height: Insets.xl),
      _SectionLabel(
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
    ref.read(shoppingListRepositoryProvider).toggleProductChecked(
      product.id,
      value,
    );
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
    final fraction = total == 0 ? 0.0 : picked / total;

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: softShadow(AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$picked',
                style: AppText.display.copyWith(color: AppColors.accent),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                'of $total picked up',
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            _encouragement,
            style: AppText.caption.copyWith(color: AppColors.inkFaint),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xxl,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.check,
                size: 32,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text('Shopping done', style: AppText.title),
            const SizedBox(height: Insets.sm),
            Text(
              total == 1
                  ? 'The one thing on your list is in the basket.'
                  : 'All $total items are in the basket. Time to cook.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tinted aisle marker — recognisable by colour while scanning.
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: Insets.md),
        Text(label, style: AppText.title.copyWith(color: color)),
        const SizedBox(width: Insets.sm),
        Text(
          '$count',
          style: AppText.caption.copyWith(color: AppColors.inkFaint),
        ),
      ],
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: softShadow(tint, opacity: 0.08),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: Material(
          color: AppColors.card,
          child: Column(
            children: [
              for (var i = 0; i < products.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 64,
                    color: AppColors.ink.withValues(alpha: 0.06),
                  ),
                _ItemRow(
                  product: products[i],
                  mealNames: mealNames,
                  onToggle: (value) => onToggle(products[i], value),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Product product;
  final Map<String, String> mealNames;
  final ValueChanged<bool> onToggle;

  const _ItemRow({
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

    final checked = product.isChecked;

    return InkWell(
      onTap: () => onToggle(!checked),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.xs, Insets.lg,
            Insets.xs),
        child: Row(
          children: [
            _CheckDot(checked: checked),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppText.title.copyWith(
                      color: checked ? AppColors.inkFaint : AppColors.ink,
                      decoration: checked ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.inkFaint,
                    ),
                    child: Text(product.name),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: AppText.caption.copyWith(
                        color: checked
                            ? AppColors.inkFaint
                            : AppColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 44×44 tap target around a 26px dot, so it stays hittable one-handed.
///
/// Ticked dots are always the accent green rather than the aisle colour:
/// "green means picked up" should mean the same thing everywhere.
class _CheckDot extends StatelessWidget {
  final bool checked;

  const _CheckDot({required this.checked});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: checked ? AppColors.accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: checked
                  ? AppColors.accent
                  : AppColors.ink.withValues(alpha: 0.22),
              width: 2,
            ),
          ),
          child: checked
              ? const FaIcon(FontAwesomeIcons.check, size: 13, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// Empty states are an opportunity: say what goes here and how to get there.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.xl),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.cartShopping,
                size: 36,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text('Nothing to buy yet', style: AppText.title),
            const SizedBox(height: Insets.sm),
            Text(
              'Add ingredients to your meals and they will show up here, '
              'grouped by aisle so you can shop straight down the list.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: Insets.xl),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
              label: const Text('Add ingredients'),
            ),
          ],
        ),
      ),
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
