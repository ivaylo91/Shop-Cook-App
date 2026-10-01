import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../data/remote/recipe_import_api.dart';
import '../../core/ui/ui.dart';
import '../pantry/pantry_match.dart';
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
  final l10n = context.l10n;

  showAppDialog<void>(
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
    messenger.replaceSnackBar(
      SnackBar(
        content: Text(switch (imported.failure) {
          ImportFailure.unreadable => l10n.importPageUnreadable,
          ImportFailure.unreachable => l10n.importUnreachable,
          _ => l10n.importNoneFound,
        }),
      ),
    );
    return;
  }

  await _offer(context, ref, imported, listId: listId, mealId: mealId);
}

/// Whether "From a photo" is offered. Off until Google Cloud Vision is
/// enabled on the server's Google project; the import function answers
/// "could not read" until then. See "Recipes from videos and photos" in
/// the README.
const photoImportEnabled = false;

/// The same, from a photo of a recipe: a cookbook page, a card from a
/// relative, a magazine clipping.
Future<void> importIngredientsFromPhoto(
  BuildContext context,
  WidgetRef ref, {
  required String listId,
  required String mealId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final source = await showAppSheet<ImageSource>(
    context: context,
    title: l10n.photoImportTitle,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const FaIcon(FontAwesomeIcons.camera, size: 16),
          title: Text(l10n.photoImportCamera),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const FaIcon(FontAwesomeIcons.image, size: 16),
          title: Text(l10n.photoImportGallery),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? photo;
  try {
    // Text stays readable at 2000 px, and the upload stays small.
    photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 80,
    );
  } catch (_) {
    messenger.replaceSnackBar(
      SnackBar(content: Text(l10n.photoImportNoCamera)),
    );
    return;
  }
  if (photo == null || !context.mounted) return;
  final bytes = await photo.readAsBytes();
  if (!context.mounted) return;

  showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LoadingDialog(),
  );
  final imported = await ref.read(recipeImportApiProvider).readPhoto(bytes);
  if (!context.mounted) return;
  Navigator.of(context).pop(); // close the loading dialog

  if (!imported.hasIngredients) {
    messenger.replaceSnackBar(
      SnackBar(
        content: Text(
          imported.failure == ImportFailure.unreachable
              ? l10n.importUnreachable
              : l10n.photoImportNoneFound,
        ),
      ),
    );
    return;
  }

  await _offer(context, ref, imported, listId: listId, mealId: mealId);
}

/// Shows what was found, ticked, for the user to choose from, then adds the
/// chosen ones to the meal.
Future<void> _offer(
  BuildContext context,
  WidgetRef ref,
  RecipeImport imported, {
  required String listId,
  required String mealId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final parsed = imported.ingredients.map(parseIngredient).toList();

  // What is already at home starts unticked, so it is not bought twice.
  final userId = ref.read(currentUserIdProvider);
  final pantry = userId == null
      ? const <String>[]
      : [
          for (final item
              in await ref.read(databaseProvider).watchPantry(userId).first)
            item.key,
        ];
  final atHome = {
    for (var i = 0; i < parsed.length; i++)
      if (isAtHome(parsed[i].name, pantry)) i,
  };
  if (!context.mounted) return;

  // Ground, radius and drag handle come from the theme's bottomSheetTheme.
  final chosen = await showModalBottomSheet<List<ParsedIngredient>>(
    context: context,
    sheetAnimationStyle: sheetMotion(context),
    isScrollControlled: true,
    builder: (context) => _IngredientPicker(
      title: imported.title,
      ingredients: parsed,
      atHome: atHome,
    ),
  );

  if (chosen == null || chosen.isEmpty) return;

  await ref
      .read(shoppingListRepositoryProvider)
      .addProducts(
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

  messenger.replaceSnackBar(
    SnackBar(content: Text(l10n.importAdded(chosen.length))),
  );
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(child: Text(context.l10n.importReading)),
        ],
      ),
    );
  }
}

class _IngredientPicker extends StatefulWidget {
  final String title;
  final List<ParsedIngredient> ingredients;

  /// Indexes of ingredients the user has at home: unticked to start with,
  /// and labelled so it is clear why.
  final Set<int> atHome;

  const _IngredientPicker({
    required this.title,
    required this.ingredients,
    this.atHome = const {},
  });

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.ingredients.length; i++)
      if (!widget.atHome.contains(i)) i,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          AppSheetHeader(
            title: widget.title.isEmpty
                ? context.l10n.importTitleDefault
                : widget.title,
            subtitle: context.l10n.importPick,
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              itemCount: widget.ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = widget.ingredients[index];
                final amount = [
                  '${ingredient.quantity} ${ingredient.unit}'.trim(),
                  if (widget.atHome.contains(index)) context.l10n.pantryTitle,
                ].where((part) => part.isNotEmpty).join(' · ');
                return CheckboxListTile(
                  value: _selected.contains(index),
                  onChanged: (value) => setState(() {
                    if (value ?? false) {
                      _selected.add(index);
                    } else {
                      _selected.remove(index);
                    }
                  }),
                  title: Text(
                    ingredient.name,
                    style: AppText.body.copyWith(color: palette.ink),
                  ),
                  subtitle: amount.isEmpty
                      ? null
                      : Text(
                          amount,
                          style: AppText.caption.copyWith(
                            color: palette.inkMuted,
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
                          ? context.l10n.importClearAll
                          : context.l10n.importSelectAll,
                    ),
                  ),
                  const Spacer(),
                  PressScale(
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, [
                              for (final i in _selected.toList()..sort())
                                widget.ingredients[i],
                            ]),
                      icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                      label: Text(
                        context.l10n.importAddCount(_selected.length),
                      ),
                    ),
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
