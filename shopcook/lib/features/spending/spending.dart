import '../../data/local/database.dart';

/// What was spent, month by month, worked out from the items themselves.
///
/// There is no separate record of purchases: an item that was ticked and
/// has a price was bought for that price. Its month is when it was cleared
/// off the list after the shop, or — while it is still on the list — when it
/// was added. Unpriced items are counted separately rather than as zero, so
/// the screen can say its totals are incomplete.
class SpendingSummary {
  /// The last six months, oldest first; the last is the current month.
  final List<({DateTime month, double total})> months;

  /// This month, by list, largest first.
  final List<({String list, double total})> byList;

  /// This month's biggest items by total spent, largest first.
  final List<({String name, double total, int times})> topItems;

  /// Items bought this month with no price, so not in the totals.
  final int unpriced;

  const SpendingSummary({
    required this.months,
    required this.byList,
    required this.topItems,
    required this.unpriced,
  });

  double get thisMonth => months.last.total;
  double get lastMonth => months[months.length - 2].total;

  /// Whether anything with a price was ever bought, i.e. whether there is
  /// anything to show at all.
  bool get isEmpty => months.every((m) => m.total == 0) && unpriced == 0;
}

SpendingSummary summarizeSpending(
  List<Product> products, {
  required Map<String, String> listNames,
  required DateTime now,
  int topCount = 5,
}) {
  final thisMonth = DateTime(now.year, now.month);
  final months = [
    for (var back = 5; back >= 0; back--)
      DateTime(thisMonth.year, thisMonth.month - back),
  ];
  final totals = {for (final month in months) month: 0.0};
  final byList = <String, double>{};
  final byItem = <String, ({String name, double total, int times})>{};
  var unpriced = 0;

  for (final product in products.where((p) => p.isChecked)) {
    final when = product.clearedAt ?? product.createdAt;
    final month = DateTime(when.year, when.month);
    final price = product.price;

    if (month == thisMonth && price == null) unpriced++;
    if (price == null || !totals.containsKey(month)) continue;

    totals[month] = totals[month]! + price;
    if (month != thisMonth) continue;

    final list = listNames[product.listId] ?? '';
    byList[list] = (byList[list] ?? 0) + price;

    final key = foldName(product.name);
    final seen = byItem[key];
    byItem[key] = (
      name: seen?.name ?? product.name,
      total: (seen?.total ?? 0) + price,
      times: (seen?.times ?? 0) + 1,
    );
  }

  final lists = [
    for (final entry in byList.entries) (list: entry.key, total: entry.value),
  ]..sort((a, b) => b.total.compareTo(a.total));
  final items = byItem.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return SpendingSummary(
    months: [for (final month in months) (month: month, total: totals[month]!)],
    byList: lists,
    topItems: items.take(topCount).toList(),
    unpriced: unpriced,
  );
}
