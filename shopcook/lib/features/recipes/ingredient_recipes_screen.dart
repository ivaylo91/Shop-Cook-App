import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/remote/recipe_search_api.dart';

/// "What can I cook with this?" for a single shopping item.
///
/// Results come back in-app through the search Edge Function. The card at the
/// top also hands the same search to the YouTube app, which is worth keeping
/// even now that in-app results work: the API returns ten videos and spends
/// quota doing it, whereas the app gives the full result list, playback and
/// comments for free.
class IngredientRecipesScreen extends ConsumerStatefulWidget {
  final Product product;

  /// Name of the meal this item belongs to, when it belongs to one. Only
  /// then is there somewhere to attach a recipe.
  final String? mealName;

  const IngredientRecipesScreen({
    super.key,
    required this.product,
    this.mealName,
  });

  @override
  ConsumerState<IngredientRecipesScreen> createState() =>
      _IngredientRecipesScreenState();
}

class _IngredientRecipesScreenState
    extends ConsumerState<IngredientRecipesScreen> {
  List<RecipeSearchResult> _results = const [];
  bool _loading = true;

  String get _query => widget.product.name;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: the locale comes from an inherited widget, which is not
    // reachable until dependencies are resolved.
    if (_started) return;
    _started = true;
    _search();
  }

  Future<void> _search({bool forceRefresh = false}) async {
    final locale = Localizations.localeOf(context).languageCode;
    setState(() => _loading = true);

    final results = await ref
        .read(recipeRepositoryProvider)
        .search(_query, locale: locale, forceRefresh: forceRefresh);

    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.cookOpenFailed)));
    }
  }

  /// Puts the result on the item's meal, or — for an item with no meal —
  /// saves it to the library, so a find is never lost for want of a meal.
  Future<void> _keep(RecipeSearchResult result) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(recipeRepositoryProvider);
    final mealId = widget.product.mealId;

    if (mealId == null) {
      await repository.saveSearchResult(userId: userId, result: result);
    } else {
      await repository.attachFromSearchResult(
        mealId: mealId,
        userId: userId,
        result: result,
      );
    }

    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mealId == null
              ? l10n.librarySaved
              : l10n.cookAttached(
                  widget.mealName ?? l10n.cookAttachedFallback,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cookWith(widget.product.name)),
        actions: [
          // Results are cached for a week; this is the way past the cache.
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
            tooltip: context.l10n.cookSearchAgain,
            onPressed: _loading ? null : () => _search(forceRefresh: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.sm,
          Insets.lg,
          Insets.xxl,
        ),
        children: [
          _SearchAppsCard(query: _query, onOpen: _open),
          const SizedBox(height: Insets.xl),
          Text(
            context.l10n.cookFromYouTube,
            style: AppText.title.copyWith(color: context.palette.ink),
          ),
          const SizedBox(height: Insets.md),
          if (_loading)
            const SkeletonRows(count: 3)
          else if (_results.isEmpty)
            const _NoResultsNote()
          else
            for (final result in _results)
              _ResultTile(
                result: result,
                onMeal: widget.product.mealId != null,
                mealName: widget.mealName,
                onOpen: () => _open(result.url),
                onKeep: () => _keep(result),
              ),
        ],
      ),
    );
  }
}

/// Straight into the YouTube app, pre-searched for this item.
class _SearchAppsCard extends StatelessWidget {
  final String query;
  final Future<void> Function(String url) onOpen;

  const _SearchAppsCard({required this.query, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    // The search term is localised too: a Bulgarian speaker looking for
    // recipes wants Bulgarian results, not a transliterated English query.
    final term = Uri.encodeQueryComponent(l10n.cookSearchQuery(query));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cookOpenYouTube,
            style: AppText.title.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            l10n.cookOpenYouTubeSubtitle(query),
            style: AppText.caption.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: Insets.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onOpen(
                'https://www.youtube.com/results?search_query=$term',
              ),
              icon: const FaIcon(FontAwesomeIcons.youtube, size: 16),
              label: const Text('YouTube'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsNote extends StatelessWidget {
  const _NoResultsNote();

  @override
  Widget build(BuildContext context) {
    return InlineNote(message: context.l10n.cookNoResults);
  }
}

class _ResultTile extends StatelessWidget {
  final RecipeSearchResult result;
  /// Whether keeping it attaches to a meal or only saves to the library.
  final bool onMeal;
  final String? mealName;
  final VoidCallback onOpen;
  final VoidCallback onKeep;

  const _ResultTile({
    required this.result,
    required this.onMeal,
    required this.mealName,
    required this.onOpen,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        padding: null,
        tint: palette.ink,
        shadowOpacity: 0.06,
        child: ListTile(
          onTap: onOpen,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          leading: result.thumbnailUrl.isEmpty
              ? const FaIcon(FontAwesomeIcons.play, size: 18)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.chip),
                  child: Image.network(
                    result.thumbnailUrl,
                    width: 72,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const FaIcon(FontAwesomeIcons.image, size: 18),
                  ),
                ),
          title: Text(
            result.title,
            style: AppText.body.copyWith(color: palette.ink),
          ),
          subtitle: Text(
            result.source,
            style: AppText.caption.copyWith(color: palette.inkMuted),
          ),
          trailing: IconButton(
            icon: FaIcon(
              onMeal ? FontAwesomeIcons.plus : FontAwesomeIcons.bookmark,
              size: 15,
            ),
            tooltip: !onMeal
                ? context.l10n.librarySave
                : mealName == null
                ? context.l10n.cookAttachToMeal
                : context.l10n.cookAttachToNamed(mealName!),
            onPressed: onKeep,
          ),
        ),
      ),
    );
  }
}
