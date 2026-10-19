import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../products/item_composer.dart' show productSuggestionsProvider;
import '../shopping/category_label.dart';
import '../shopping/product_category.dart';

/// A row of aisle tiles at the top of a list: tap one and the things you
/// usually buy from that aisle come up, each one tap from the list.
///
/// For the weekly shop typed from memory, where "what did we need from the
/// dairy?" is easier to answer from a short list than from a blank field.
class QuickAddAisles extends StatelessWidget {
  final String listId;

  const QuickAddAisles({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Flush with the cards under it, and able to scroll to the edge.
        clipBehavior: Clip.none,
        itemCount: ProductCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
        itemBuilder: (context, index) {
          final category = ProductCategory.values[index];
          return AisleTile(
            category: category,
            width: 80,
            maxLines: 2,
            onTap: () => showQuickAdd(context, listId: listId, aisle: category),
          );
        },
      ),
    );
  }
}

/// The aisles as a grid of four across, for the home screen: every aisle
/// but "other", which has no starters to offer.
class AisleGrid extends StatelessWidget {
  final String listId;

  const AisleGrid({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    final aisles = [
      for (final category in ProductCategory.values)
        if (category != ProductCategory.other) category,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        final width = constraints.maxWidth / columns;
        return Wrap(
          runSpacing: Insets.md,
          children: [
            for (final category in aisles)
              SizedBox(
                width: width,
                child: Center(
                  child: AisleTile(
                    category: category,
                    // The full name on two lines: "Плодове и зеленчуци"
                    // cut to "Плодове и …" said less than nothing.
                    width: width,
                    maxLines: 2,
                    onTap: () =>
                        showQuickAdd(context, listId: listId, aisle: category),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One aisle: its picture on its own pastel tile, and its name.
class AisleTile extends StatelessWidget {
  final ProductCategory category;
  final VoidCallback onTap;
  final double width;
  final int maxLines;

  const AisleTile({
    super.key,
    required this.category,
    required this.onTap,
    this.width = 76,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = category.label(context.l10n);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: palette.aisleTile(category),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Illustration(Art.of(category), size: 50),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: maxLines,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet for one aisle: what you have bought from it before, most used
/// first, then a few common things, each a chip that adds it to the list.
Future<void> showQuickAdd(
  BuildContext context, {
  required String listId,
  required ProductCategory aisle,
}) {
  return showAppSheet<void>(
    context: context,
    title: aisle.label(context.l10n),
    builder: (context) => _QuickAddSheet(listId: listId, aisle: aisle),
  );
}

/// The names offered for [aisle]: the user's own first, by how often they
/// were bought, then [starters] they have not bought yet. Compared without
/// case, so "milk" in the history hides the starter "Milk".
List<String> quickAddNames({
  required ProductCategory aisle,
  required List<({String name, int uses})> history,
  required List<String> starters,
  int limit = 24,
}) {
  final seen = <String>{};
  final names = <String>[];
  final own = [...history.where((h) => categorize(h.name) == aisle)]
    ..sort((a, b) => b.uses.compareTo(a.uses));
  for (final name in [for (final h in own) h.name, ...starters]) {
    if (seen.add(name.trim().toLowerCase())) names.add(name.trim());
    if (names.length == limit) break;
  }
  return names;
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  final String listId;
  final ProductCategory aisle;

  const _QuickAddSheet({required this.listId, required this.aisle});

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  /// Added from this sheet, so a chip shows it went on.
  final _added = <String>{};

  /// The chips as they were when the sheet opened. Kept, because an add
  /// puts the item into the history, which would otherwise re-sort the
  /// chips under the finger reaching for the next one.
  List<String>? _names;

  Future<void> _add(String name) async {
    if (_added.contains(name)) return;
    HapticFeedback.selectionClick();
    setState(() => _added.add(name));
    await ref
        .read(shoppingListRepositoryProvider)
        .addOrMergeProduct(listId: widget.listId, name: name);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final suggestionsAsync = ref.watch(productSuggestionsProvider);
    final suggestions = suggestionsAsync.valueOrNull ?? const [];
    final computed = quickAddNames(
      aisle: widget.aisle,
      history: [for (final s in suggestions) (name: s.name, uses: s.uses)],
      starters: starterItems(widget.aisle, language),
    );
    // Fixed once the history has loaded; until then, follow it.
    if (suggestionsAsync.hasValue) _names ??= computed;
    final names = _names ?? computed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Illustration(Art.of(widget.aisle), size: 96)),
          const SizedBox(height: Insets.md),
          Text(
            l10n.quickAddHint,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: Insets.lg),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final name in names)
                _added.contains(name)
                    ? InputChip(
                        avatar: FaIcon(
                          FontAwesomeIcons.check,
                          size: 12,
                          color: palette.onAccent,
                        ),
                        label: Text(
                          name,
                          style: TextStyle(color: palette.onAccent),
                        ),
                        backgroundColor: palette.accent,
                        side: BorderSide.none,
                        onPressed: () {},
                      )
                    : ActionChip(
                        avatar: FaIcon(
                          FontAwesomeIcons.plus,
                          size: 11,
                          color: palette.accent,
                        ),
                        label: Text(name),
                        backgroundColor: palette.glass,
                        side: BorderSide(color: palette.divider),
                        onPressed: () => _add(name),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A few common things from each aisle, for someone whose history does not
/// cover it yet. In the app's language: Bulgarian, or English otherwise.
List<String> starterItems(ProductCategory aisle, String language) {
  final bg = language == 'bg';
  return switch (aisle) {
    ProductCategory.produce =>
      bg
          ? [
              'Домати',
              'Краставици',
              'Картофи',
              'Лук',
              'Чесън',
              'Моркови',
              'Банани',
              'Ябълки',
              'Лимони',
            ]
          : [
              'Tomatoes',
              'Cucumbers',
              'Potatoes',
              'Onions',
              'Garlic',
              'Carrots',
              'Bananas',
              'Apples',
              'Lemons',
            ],
    ProductCategory.bakery =>
      bg
          ? ['Хляб', 'Питка', 'Багета', 'Кифли', 'Кори за баница']
          : ['Bread', 'Baguette', 'Rolls', 'Croissants', 'Tortillas'],
    ProductCategory.meatAndFish =>
      bg
          ? ['Пилешко филе', 'Кайма', 'Свинско', 'Наденица', 'Шунка', 'Сьомга']
          : [
              'Chicken breast',
              'Minced meat',
              'Pork',
              'Sausages',
              'Ham',
              'Salmon',
            ],
    ProductCategory.dairyAndEggs =>
      bg
          ? [
              'Прясно мляко',
              'Кисело мляко',
              'Сирене',
              'Кашкавал',
              'Масло',
              'Яйца',
            ]
          : ['Milk', 'Yoghurt', 'Cheese', 'Butter', 'Eggs', 'Cream'],
    ProductCategory.frozen =>
      bg
          ? ['Замразен грах', 'Сладолед', 'Замразени зеленчуци', 'Пица']
          : ['Frozen peas', 'Ice cream', 'Frozen vegetables', 'Pizza'],
    ProductCategory.pantry =>
      bg
          ? [
              'Олио',
              'Зехтин',
              'Ориз',
              'Макарони',
              'Брашно',
              'Захар',
              'Сол',
              'Боб',
            ]
          : [
              'Olive oil',
              'Rice',
              'Pasta',
              'Flour',
              'Sugar',
              'Salt',
              'Beans',
              'Tomato paste',
            ],
    ProductCategory.drinks =>
      bg
          ? ['Вода', 'Кафе', 'Чай', 'Портокалов сок', 'Бира']
          : ['Water', 'Coffee', 'Tea', 'Orange juice', 'Beer'],
    ProductCategory.household =>
      bg
          ? [
              'Тоалетна хартия',
              'Препарат за съдове',
              'Прах за пране',
              'Торби за боклук',
              'Сапун',
            ]
          : [
              'Toilet paper',
              'Dish soap',
              'Laundry detergent',
              'Bin bags',
              'Soap',
            ],
    ProductCategory.other => const [],
  };
}
