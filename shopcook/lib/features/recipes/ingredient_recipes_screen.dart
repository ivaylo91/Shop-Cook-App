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
/// YouTube results come back in-app through the search Edge Function once an
/// API key is configured. TikTok has no public search API — the Display API
/// only reaches the signed-in user's own videos and the Research API needs
/// approval — so TikTok is offered as a one-tap search in its own app, which
/// needs no key and works today.
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

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    final results = await ref.read(recipeRepositoryProvider).search(_query);
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

  Future<void> _attach(RecipeSearchResult result) async {
    final mealId = widget.product.mealId;
    if (mealId == null) return;

    await ref
        .read(recipeRepositoryProvider)
        .attachFromSearchResult(mealId, result);

    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.cookAttached(widget.mealName ?? l10n.cookAttachedFallback),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cookWith(widget.product.name)),
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
                canAttach: widget.product.mealId != null,
                mealName: widget.mealName,
                onOpen: () => _open(result.url),
                onAttach: () => _attach(result),
              ),
        ],
      ),
    );
  }
}

/// Straight into the YouTube and TikTok apps, pre-searched for this item.
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
            l10n.cookSearchApps,
            style: AppText.title.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            l10n.cookSearchAppsSubtitle(query),
            style: AppText.caption.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onOpen(
                    'https://www.youtube.com/results?search_query=$term',
                  ),
                  icon: const FaIcon(FontAwesomeIcons.youtube, size: 16),
                  label: const Text('YouTube'),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      onOpen('https://www.tiktok.com/search?q=$term'),
                  icon: const FaIcon(FontAwesomeIcons.tiktok, size: 16),
                  label: const Text('TikTok'),
                  // TikTok's own black, so the two buttons read as two
                  // destinations rather than one repeated action.
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.ink,
                    foregroundColor: palette.card,
                  ),
                ),
              ),
            ],
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
  final bool canAttach;
  final String? mealName;
  final VoidCallback onOpen;
  final VoidCallback onAttach;

  const _ResultTile({
    required this.result,
    required this.canAttach,
    required this.mealName,
    required this.onOpen,
    required this.onAttach,
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
          trailing: canAttach
              ? IconButton(
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 15),
                  tooltip: mealName == null
                      ? context.l10n.cookAttachToMeal
                      : context.l10n.cookAttachToNamed(mealName!),
                  onPressed: onAttach,
                )
              : null,
        ),
      ),
    );
  }
}
