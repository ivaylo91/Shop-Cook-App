import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/repositories/shopping_list_repository.dart';
import '../shopping/category_label.dart';
import '../shopping/product_category.dart';

/// Everything you can do to one item, in one sheet.
///
/// The price, aisle and staple actions apply anywhere an item appears, so they
/// live here. The rest depend on where you opened it from — there is no meal
/// to move to while shopping, and no reason to delete from the aisle view — so
/// each screen passes in the ones that make sense. One sheet rather than one
/// per screen, because the per-screen versions had already drifted into
/// offering different things in different orders.
Future<void> showItemSheet(
  BuildContext context,
  WidgetRef ref,
  Product product, {
  VoidCallback? onFindRecipes,
  VoidCallback? onMoveToMeal,
  VoidCallback? onDelete,
}) async {
  final l10n = context.l10n;
  final palette = context.palette;
  final priced = product.price != null;
  final aisle = ShoppingListRepository.aisleOf(product);

  final action = await showAppSheet<String>(
    context: context,
    title: product.name,
    subtitle: priced ? context.money(product.price!) : null,
    builder: (context) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onFindRecipes != null)
            ListTile(
              leading: const FaIcon(
                FontAwesomeIcons.magnifyingGlass,
                size: 16,
              ),
              title: Text(l10n.itemFindRecipes),
              onTap: () => Navigator.pop(context, 'recipes'),
            ),
          if (onMoveToMeal != null)
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.utensils, size: 16),
              title: Text(l10n.itemMoveToMeal),
              onTap: () => Navigator.pop(context, 'meal'),
            ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.tag, size: 16),
            title: Text(l10n.itemSetPrice),
            subtitle: priced ? Text(context.money(product.price!)) : null,
            onTap: () => Navigator.pop(context, 'price'),
          ),
          ListTile(
            leading: FaIcon(
              aisle.icon,
              size: 16,
              color: palette.aisle(aisle),
            ),
            title: Text(l10n.itemMoveToAisle),
            subtitle: Text(aisle.label(l10n)),
            onTap: () => Navigator.pop(context, 'aisle'),
          ),
          ListTile(
            leading: FaIcon(
              product.isStaple
                  ? FontAwesomeIcons.solidStar
                  : FontAwesomeIcons.star,
              size: 16,
              color: product.isStaple ? palette.accent : null,
            ),
            title: Text(
              product.isStaple ? l10n.itemUnmarkStaple : l10n.itemMarkStaple,
            ),
            onTap: () => Navigator.pop(context, 'staple'),
          ),
          if (onDelete != null)
            ListTile(
              leading: FaIcon(
                FontAwesomeIcons.trashCan,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.actionDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;
  final repository = ref.read(shoppingListRepositoryProvider);

  switch (action) {
    case 'recipes':
      onFindRecipes?.call();

    case 'meal':
      onMoveToMeal?.call();

    case 'delete':
      onDelete?.call();

    case 'staple':
      await repository.setStaple(product.id, !product.isStaple);

    case 'price':
      final entry = await promptForPrice(
        context,
        title: l10n.itemPriceTitle(product.name),
        initialValue: product.price,
      );
      // Null means cancelled; a PriceEntry holding null means "clear it".
      if (entry == null) return;
      await repository.setPrice(product.id, entry.value);

    case 'aisle':
      await _pickAisle(context, ref, product);
  }
}

/// Files the item in an aisle by hand.
///
/// The correction is stored against the name rather than the row, so fixing
/// "halloumi" once fixes it for every future shop.
Future<void> _pickAisle(
  BuildContext context,
  WidgetRef ref,
  Product product,
) async {
  final l10n = context.l10n;
  final palette = context.palette;
  final current = ShoppingListRepository.aisleOf(product);

  final chosen = await showAppSheet<_AislePick>(
    context: context,
    title: l10n.itemAisleTitle(product.name),
    builder: (context) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(
              FontAwesomeIcons.wandMagicSparkles,
              size: 15,
            ),
            title: Text(l10n.itemAisleAuto),
            subtitle: Text(l10n.itemAisleAutoSubtitle),
            onTap: () => Navigator.pop(context, const _AislePick(null)),
          ),
          const Divider(height: 1),
          for (final category in ProductCategory.values)
            ListTile(
              leading: FaIcon(
                category.icon,
                size: 16,
                color: palette.aisle(category),
              ),
              title: Text(category.label(l10n)),
              trailing: category == current
                  ? FaIcon(
                      FontAwesomeIcons.check,
                      size: 13,
                      color: palette.accent,
                    )
                  : null,
              onTap: () => Navigator.pop(context, _AislePick(category)),
            ),
        ],
      ),
    ),
  );

  if (chosen == null) return;

  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  await ref.read(shoppingListRepositoryProvider).setAisle(
    userId: userId,
    name: product.name,
    category: chosen.category,
  );
}

/// Wraps the choice so "sort it automatically" (null) is distinguishable from
/// a cancelled sheet, which also yields null.
class _AislePick {
  final ProductCategory? category;

  const _AislePick(this.category);
}
