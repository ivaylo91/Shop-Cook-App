import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import 'ingredient_parser.dart';

/// Runs the import end to end: fetch, let the user choose, then insert.
///
/// Parsing free-text ingredient lines is imperfect, so nothing is added
/// without the user seeing exactly what will land on the list.
Future<void> importIngredients(
  BuildContext context,
  WidgetRef ref, {
  required String recipeUrl,
  required String listId,
  required String mealId,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LoadingDialog(),
  );

  final imported = await ref
      .read(recipeImportApiProvider)
      .fetchIngredients(recipeUrl);

  if (!context.mounted) return;
  Navigator.of(context).pop(); // close the loading dialog

  if (!imported.hasIngredients) {
    messenger.showSnackBar(
      SnackBar(content: Text(imported.error ?? 'No ingredients found.')),
    );
    return;
  }

  final parsed = imported.ingredients.map(parseIngredient).toList();

  final chosen = await showModalBottomSheet<List<ParsedIngredient>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
    ),
    builder: (context) => _IngredientPicker(
      title: imported.title,
      ingredients: parsed,
    ),
  );

  if (chosen == null || chosen.isEmpty) return;

  await ref.read(shoppingListRepositoryProvider).addProducts(
    listId: listId,
    mealId: mealId,
    items: [
      for (final ingredient in chosen)
        (
          name: ingredient.name,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
        ),
    ],
  );

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        chosen.length == 1
            ? 'Added 1 ingredient.'
            : 'Added ${chosen.length} ingredients.',
      ),
    ),
  );
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: Insets.lg),
          Expanded(child: Text('Reading the recipe…')),
        ],
      ),
    );
  }
}

class _IngredientPicker extends StatefulWidget {
  final String title;
  final List<ParsedIngredient> ingredients;

  const _IngredientPicker({required this.title, required this.ingredients});

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.ingredients.length; i++) i,
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.xl,
              Insets.xl,
              Insets.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.isEmpty ? 'Ingredients' : widget.title,
                  style: AppText.title,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Pick what to add to this meal.',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              itemCount: widget.ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = widget.ingredients[index];
                final amount = '${ingredient.quantity} ${ingredient.unit}'
                    .trim();
                return CheckboxListTile(
                  value: _selected.contains(index),
                  onChanged: (value) => setState(() {
                    if (value ?? false) {
                      _selected.add(index);
                    } else {
                      _selected.remove(index);
                    }
                  }),
                  title: Text(ingredient.name, style: AppText.body),
                  subtitle: amount.isEmpty
                      ? null
                      : Text(
                          amount,
                          style: AppText.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                  dense: true,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selected.length == widget.ingredients.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll([
                          for (var i = 0; i < widget.ingredients.length; i++) i,
                        ]);
                      }
                    }),
                    child: Text(
                      _selected.length == widget.ingredients.length
                          ? 'Clear all'
                          : 'Select all',
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, [
                            for (final i in _selected.toList()..sort())
                              widget.ingredients[i],
                          ]),
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                    label: Text('Add ${_selected.length}'),
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
