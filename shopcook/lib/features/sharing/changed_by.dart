import 'package:flutter/widgets.dart';

import '../../core/localization.dart';
import '../../data/local/database.dart';

/// "by Anna", for an item in a shared list that someone else changed last;
/// null for everything else, including the user's own changes.
String? changedByLabel(
  BuildContext context,
  Product product, {
  required Map<String, String> names,
  required String? me,
}) {
  final by = product.changedBy;
  if (by == null || by == me) return null;
  final name = names[by] ?? '';
  return context.l10n.changedBy(name.isEmpty ? context.l10n.someone : name);
}
