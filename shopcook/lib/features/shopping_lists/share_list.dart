import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization.dart';
import '../../data/local/database.dart';
import '../../data/repositories/shopping_list_repository.dart';
import '../shopping/category_label.dart';
import '../shopping/product_category.dart';

/// Sends the list somewhere else as plain text.
///
/// This is the cheap nine-tenths of cloud sync. The everyday need is "tell my
/// partner what to buy", not shared mutable state across devices — and plain
/// text reaches every messaging app, needs no account on the other end, and
/// works with no signal beyond whatever the messenger itself needs.
///
/// Grouped by aisle in the user's own order, because a list you are about to
/// read in a shop wants the same shape as shopping mode.
Future<void> shareList(
  BuildContext context, {
  required ShoppingList list,
  required List<Product> products,
  required List<ProductCategory> aisleOrder,
}) async {
  final l10n = context.l10n;
  final remaining = products.where((p) => !p.isChecked).toList();

  if (remaining.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.shareNothing)),
    );
    return;
  }

  final lines = <String>[list.name, ''];

  for (final category in aisleOrder) {
    final items = remaining
        .where((p) => ShoppingListRepository.aisleOf(p) == category)
        .toList();
    if (items.isEmpty) continue;

    lines.add('${category.label(l10n)}:');
    for (final item in items) {
      final amount = '${item.quantity} ${item.unit}'.trim();
      lines.add(amount.isEmpty ? '- ${item.name}' : '- ${item.name} — $amount');
    }
    lines.add('');
  }

  await SharePlus.instance.share(
    ShareParams(
      text: lines.join('\n').trimRight(),
      subject: l10n.shareListSubject(list.name),
    ),
  );
}
