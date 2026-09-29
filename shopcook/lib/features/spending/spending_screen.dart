import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import 'spending.dart';

/// What the shopping has cost: this month against last, the last six
/// months, and where this month's money went.
class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final summary = ref.watch(_spendingProvider).valueOrNull;

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l10n.spendingTitle)),
        body: summary == null
            ? const Padding(
                padding: EdgeInsets.all(Insets.lg),
                child: SkeletonRows(count: 3),
              )
            : summary.isEmpty
            ? EmptyState(
                icon: FontAwesomeIcons.chartColumn,
                title: l10n.spendingEmptyTitle,
                message: l10n.spendingEmptyMessage,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.lg,
                  Insets.lg,
                  Insets.xxl,
                ),
                children: [
                  _ThisMonth(summary: summary),
                  const SizedBox(height: Insets.lg),
                  _MonthBars(summary: summary),
                  if (summary.byList.length > 1) ...[
                    const SizedBox(height: Insets.xl),
                    SectionLabel(
                      icon: FontAwesomeIcons.rectangleList,
                      label: l10n.spendingByList,
                      color: palette.accent,
                    ),
                    const SizedBox(height: Insets.md),
                    AppCardList(
                      tint: palette.accent,
                      dividerIndent: Insets.lg,
                      children: [
                        for (final row in summary.byList)
                          _AmountRow(label: row.list, amount: row.total),
                      ],
                    ),
                  ],
                  if (summary.topItems.isNotEmpty) ...[
                    const SizedBox(height: Insets.xl),
                    SectionLabel(
                      icon: FontAwesomeIcons.basketShopping,
                      label: l10n.spendingTopItems,
                      color: palette.accent,
                    ),
                    const SizedBox(height: Insets.md),
                    AppCardList(
                      tint: palette.accent,
                      dividerIndent: Insets.lg,
                      children: [
                        for (final item in summary.topItems)
                          _AmountRow(
                            label: item.name,
                            detail: item.times > 1
                                ? l10n.spendingTimes(item.times)
                                : null,
                            amount: item.total,
                          ),
                      ],
                    ),
                  ],
                  if (summary.unpriced > 0) ...[
                    const SizedBox(height: Insets.lg),
                    InlineNote(
                      message: l10n.spendingUnpriced(summary.unpriced),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ThisMonth extends StatelessWidget {
  final SpendingSummary summary;

  const _ThisMonth({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(Insets.xl),
      shadowOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.spendingThisMonth,
            style: AppText.caption.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            context.money(summary.thisMonth),
            style: AppText.title.copyWith(
              fontSize: 34,
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            l10n.spendingLastMonth(context.money(summary.lastMonth)),
            style: AppText.caption.copyWith(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Six months as bars, the current one in the accent colour.
class _MonthBars extends StatelessWidget {
  final SpendingSummary summary;

  const _MonthBars({required this.summary});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final highest = summary.months
        .map((m) => m.total)
        .fold<double>(0, (a, b) => a > b ? a : b);
    const barArea = 120.0;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.xl,
        Insets.lg,
        Insets.lg,
      ),
      shadowOpacity: 0.07,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, month) in summary.months.indexed)
            Expanded(
              child: Semantics(
                label:
                    '${DateFormat('MMMM', locale).format(month.month)}: '
                    '${context.money(month.total)}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    SizedBox(
                      height: barArea,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 0.55,
                          heightFactor: highest == 0
                              ? 0.02
                              : (month.total / highest).clamp(0.02, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: index == summary.months.length - 1
                                  ? palette.accent
                                  : palette.accent.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      DateFormat('MMM', locale).format(month.month),
                      style: AppText.caption.copyWith(color: palette.inkMuted),
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

class _AmountRow extends StatelessWidget {
  final String label;
  final String? detail;
  final double amount;

  const _AmountRow({required this.label, required this.amount, this.detail});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListTile(
      title: Text(label, overflow: TextOverflow.ellipsis),
      subtitle: detail == null ? null : Text(detail!),
      trailing: Text(
        context.money(amount),
        style: AppText.body.copyWith(
          color: palette.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final _spendingProvider = StreamProvider<SpendingSummary>((ref) async* {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;
  final db = ref.watch(databaseProvider);

  await for (final products in db.watchAllProductsForUser(userId)) {
    final lists = await db.watchLists(userId).first;
    yield summarizeSpending(
      products,
      listNames: {for (final list in lists) list.id: list.name},
      now: DateTime.now(),
    );
  }
});
