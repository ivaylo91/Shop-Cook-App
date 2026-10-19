import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/repositories/recipe_repository.dart';
import 'library_search.dart';
import 'recipe_link_dialog.dart';
import 'recipe_thumbnail.dart';

/// Every recipe the user has kept, independent of any meal.
///
/// Recipes used to belong to exactly one meal and vanish with it, so the
/// bolognese found last month had to be found again this month. Here it
/// stays, and goes onto as many meals as it is cooked for.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// Which recipes the chips at the top of the library let through.
enum _Filter { all, inMeal, noMeal }

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';
  bool _searching = false;
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final libraryAsync = ref.watch(libraryProvider);
    ref.listen(libraryProvider, (_, next) {
      final library = next.valueOrNull;
      if (library == null) return;
      ref
          .read(recipeRepositoryProvider)
          .fillMissingDetails(library.map((e) => e.recipe));
    });

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ScreenHeader(
          title: l10n.navRecipes,
          trailing: [
            RoundIconButton(
              icon: _searching
                  ? FontAwesomeIcons.xmark
                  : FontAwesomeIcons.magnifyingGlass,
              tooltip: l10n.librarySearchHint,
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query = '';
              }),
            ),
          ],
        ),
        body: libraryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: SkeletonRows(count: 3),
          ),
          error: (_, __) =>
              ErrorState(onRetry: () => ref.invalidate(libraryProvider)),
          data: (library) {
            final inMeal = library.where((e) => e.mealCount > 0).length;
            final shown = [
              for (final entry in library)
                if (recipeMatches(entry.recipe, _query) &&
                    switch (_filter) {
                      _Filter.all => true,
                      _Filter.inMeal => entry.mealCount > 0,
                      _Filter.noMeal => entry.mealCount == 0,
                    })
                  entry,
            ];

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                96,
              ),
              children: [
                if (_searching) ...[
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.librarySearchHint,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(Insets.md),
                        child: FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                ],
                const _ImportCard(),
                if (library.isEmpty)
                  EmptyState(
                    art: Art.cooking,
                    icon: FontAwesomeIcons.bookOpen,
                    title: l10n.libraryEmptyTitle,
                    message: l10n.libraryEmptyMessage,
                  )
                else ...[
                  const SizedBox(height: Insets.lg),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (final (filter, label) in [
                          (_Filter.all, l10n.libraryFilterAll(library.length)),
                          (_Filter.inMeal, l10n.libraryFilterInMeal(inMeal)),
                          (
                            _Filter.noMeal,
                            l10n.libraryFilterNoMeal(library.length - inMeal),
                          ),
                        ]) ...[
                          _FilterChip(
                            label: label,
                            selected: _filter == filter,
                            onTap: () => setState(() => _filter = filter),
                          ),
                          const SizedBox(width: Insets.sm),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  if (shown.isEmpty)
                    InlineNote(message: l10n.libraryNoMatch(_query.trim())),
                  for (final (index, entry) in shown.indexed) ...[
                    if (index > 0) const SizedBox(height: Insets.md),
                    _LibraryCard(entry: entry),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The banner at the top of the library: paste a link, and the recipe is
/// kept, its ingredients ready to go onto a list.
class _ImportCard extends ConsumerStatefulWidget {
  const _ImportCard();

  @override
  ConsumerState<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends ConsumerState<_ImportCard> {
  final _link = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _busy) return;

    final url = normaliseRecipeUrl(_link.text);
    if (url == null) {
      // Nothing typed: the full dialog, which also takes a title.
      if (_link.text.trim().isEmpty) {
        await addLinkToLibrary(context, ref);
      } else {
        messenger.replaceSnackBar(
          SnackBar(content: Text(l10n.libraryLinkInvalid)),
        );
      }
      return;
    }

    setState(() => _busy = true);
    await ref
        .read(recipeRepositoryProvider)
        .saveRecipe(
          userId: userId,
          title: '',
          sourceUrl: url,
          sourceType: RecipeRepository.typeOfUrl(url),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    _link.clear();
    FocusScope.of(context).unfocus();
    messenger.replaceSnackBar(SnackBar(content: Text(l10n.librarySaved)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.hero),
        gradient: LinearGradient(
          begin: const Alignment(-1, -0.58),
          end: const Alignment(1, 0.58),
          colors: palette.isDark
              ? const [Color(0xFF2E2819), Color(0xFF1F3A2C)]
              : const [Color(0xFFFBEBD5), Color(0xFFD9F0E3)],
        ),
        border: Border.all(color: palette.glassEdge),
        boxShadow: palette.shadow(palette.accent, opacity: 0.10),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -10,
            top: -6,
            child: Illustration(Art.cooking, size: 116),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 96),
                  child: Text(
                    l10n.libraryImportTitle,
                    style: AppText.title.copyWith(
                      fontSize: 19,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: palette.heroInk,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Padding(
                  padding: const EdgeInsets.only(right: 96),
                  child: Text(
                    l10n.libraryImportSubtitle,
                    style: AppText.caption.copyWith(color: palette.inkMuted),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Container(
                  height: 52,
                  padding: const EdgeInsets.only(left: Insets.lg, right: 6),
                  decoration: BoxDecoration(
                    color: palette.floating,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.link,
                        size: 14,
                        color: palette.inkMuted,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: TextField(
                          controller: _link,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                          decoration: InputDecoration(
                            hintText: l10n.libraryPasteLink,
                            filled: false,
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: Insets.md,
                            ),
                          ),
                        ),
                      ),
                      PressScale(
                        child: FilledButton(
                          onPressed: _busy ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.lg,
                            ),
                          ),
                          child: _busy
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.onAccent,
                                  ),
                                )
                              : Text(l10n.libraryImportAction),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill that narrows the library: filled when chosen.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? palette.accent : palette.floating,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? palette.onAccent : palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a link and saves it to the library. Public so the share-sheet
/// intake can land a shared link in the same place.
Future<void> addLinkToLibrary(
  BuildContext context,
  WidgetRef ref, {
  String initialUrl = '',
  String initialTitle = '',
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  final link = await promptForRecipeLink(
    context,
    initialUrl: initialUrl,
    title: initialTitle,
  );
  if (link == null) return;

  await ref
      .read(recipeRepositoryProvider)
      .saveRecipe(
        userId: userId,
        title: link.title,
        sourceUrl: link.url,
        sourceType: RecipeRepository.typeOfUrl(link.url),
      );

  messenger.replaceSnackBar(SnackBar(content: Text(l10n.librarySaved)));
}

class _LibraryCard extends ConsumerWidget {
  final LibraryRecipe entry;

  const _LibraryCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final recipe = entry.recipe;
    final isVideo = recipe.sourceType == RecipeSourceType.video;

    final inMeal = entry.mealCount > 0;

    return AppCard(
      padding: const EdgeInsets.all(10),
      tint: palette.ink,
      shadowOpacity: 0.06,
      onTap: () => context.push('/recipe', extra: recipe),
      onLongPress: () => _actions(context, ref),
      child: Row(
        children: [
          RecipeThumbnail(
            url: recipe.thumbnailUrl,
            isVideo: isVideo,
            width: 84,
            height: 84,
            radius: 16,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: AppText.body.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.xs),
                Row(
                  children: [
                    FaIcon(
                      isVideo
                          ? FontAwesomeIcons.youtube
                          : FontAwesomeIcons.globe,
                      size: 12,
                      color: isVideo
                          ? const Color(0xFFD93025)
                          : palette.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isVideo
                            ? l10n.recipeSourceVideo
                            : l10n.recipeSourceWeb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: inMeal
                        ? palette.accent.withValues(
                            alpha: palette.isDark ? 0.22 : 0.14,
                          )
                        : palette.sunken,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.libraryBadgeMeals(entry.mealCount),
                    style: AppText.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: inMeal ? palette.heroInk : palette.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 15),
            tooltip: l10n.itemActions,
            onPressed: () => _actions(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;

    final action = await showAppSheet<String>(
      context: context,
      title: entry.recipe.title,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.kitchenSet, size: 16),
            title: Text(l10n.cookModeStart),
            onTap: () => Navigator.pop(context, 'cook'),
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.utensils, size: 16),
            title: Text(l10n.libraryAddToMeal),
            onTap: () => Navigator.pop(context, 'meal'),
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.trashCan, size: 16, color: error),
            title: Text(
              l10n.libraryDeleteForGood,
              style: TextStyle(color: error),
            ),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'cook':
        await context.push('/cook', extra: entry.recipe);
      case 'meal':
        await _addToMeal(context, ref);
      case 'delete':
        await _delete(context, ref);
    }
  }

  Future<void> _addToMeal(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(recipeRepositoryProvider);
    final meals = await repository.mealsForUser(userId);
    if (!context.mounted) return;

    if (meals.isEmpty) {
      messenger.replaceSnackBar(SnackBar(content: Text(l10n.libraryNoMeals)));
      return;
    }

    final picked = await showAppSheet<Meal>(
      context: context,
      title: l10n.libraryPickMeal,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in meals)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.utensils, size: 16),
                title: Text(option.meal.name),
                // Meal names repeat across weeks; the list says which one.
                subtitle: Text(option.listName),
                onTap: () => Navigator.pop(context, option.meal),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;

    await repository.linkToMeal(mealId: picked.id, recipeId: entry.recipe.id);
    messenger.replaceSnackBar(
      SnackBar(content: Text(l10n.libraryAdded(picked.name))),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await confirmAction(
      context,
      title: l10n.libraryDeleteTitle,
      message: l10n.libraryDeleteMessage,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;

    await ref.read(recipeRepositoryProvider).deleteRecipe(entry.recipe.id);
    messenger.replaceSnackBar(SnackBar(content: Text(l10n.libraryDeleted)));
  }
}

final libraryProvider = StreamProvider<List<LibraryRecipe>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(recipeRepositoryProvider).watchLibrary(userId);
});
