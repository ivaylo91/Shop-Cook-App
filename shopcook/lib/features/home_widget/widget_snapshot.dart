import '../../data/local/database.dart';

/// What the home screen widget shows, worked out from the lists.
class WidgetSnapshot {
  /// The list shown, or null when there are no lists.
  final ShoppingList? list;

  /// Unticked items on it.
  final int left;

  /// Item lines to print, already cut to fit.
  final List<String> lines;

  /// How many unticked items did not fit.
  final int more;

  const WidgetSnapshot({
    required this.list,
    required this.left,
    required this.lines,
    required this.more,
  });

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.list?.id == list?.id &&
      other.list?.name == list?.name &&
      other.left == left &&
      other.more == more &&
      _sameLines(other.lines, lines);

  @override
  int get hashCode => Object.hash(list?.id, list?.name, left, more, lines.length);

  static bool _sameLines(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Picks the list with the most still to buy — the one a glance at the home
/// screen is most likely for. Ties go to the newest list, which is the order
/// [lists] arrives in. With nothing left anywhere, the newest list is shown
/// as done rather than showing nothing.
WidgetSnapshot pickWidgetSnapshot(
  List<ShoppingList> lists,
  List<Product> products, {
  int maxLines = 6,
}) {
  if (lists.isEmpty) {
    return const WidgetSnapshot(list: null, left: 0, lines: [], more: 0);
  }

  final unticked = <String, List<Product>>{};
  for (final product in products) {
    if (product.isChecked) continue;
    unticked.putIfAbsent(product.listId, () => []).add(product);
  }

  var chosen = lists.first;
  for (final list in lists) {
    if ((unticked[list.id]?.length ?? 0) >
        (unticked[chosen.id]?.length ?? 0)) {
      chosen = list;
    }
  }

  final items = [...?unticked[chosen.id]]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final shown = items.take(maxLines).map(_line).toList();

  return WidgetSnapshot(
    list: chosen,
    left: items.length,
    lines: shown,
    more: items.length - shown.length,
  );
}

String _line(Product product) {
  final amount = '${product.quantity} ${product.unit}'.trim();
  return amount.isEmpty ? product.name : '${product.name} · $amount';
}
