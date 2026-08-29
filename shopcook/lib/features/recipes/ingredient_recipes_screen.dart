import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
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
      ).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
    }
  }

  Future<void> _attach(RecipeSearchResult result) async {
    final mealId = widget.product.mealId;
    if (mealId == null) return;

    await ref
        .read(recipeRepositoryProvider)
        .attachFromSearchResult(mealId, result);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attached to ${widget.mealName ?? 'the meal'}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Cook with ${widget.product.name}', style: AppText.title),
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
          Text('From YouTube', style: AppText.title),
          const SizedBox(height: Insets.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: Center(child: CircularProgressIndicator()),
            )
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
    final term = Uri.encodeQueryComponent('$query recipe');

    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: softShadow(AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Search the apps', style: AppText.title),
          const SizedBox(height: Insets.xs),
          Text(
            'Opens a search for "$query recipe".',
            style: AppText.caption.copyWith(color: AppColors.inkMuted),
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
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      onOpen('https://www.tiktok.com/search?q=$term'),
                  icon: const FaIcon(FontAwesomeIcons.tiktok, size: 16),
                  label: const Text('TikTok'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    minimumSize: const Size.fromHeight(48),
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
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(
            FontAwesomeIcons.circleInfo,
            size: 15,
            color: AppColors.inkFaint,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'No in-app results yet. These appear once a YouTube API key is '
              'set on the backend — until then, use the buttons above.',
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
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
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: softShadow(AppColors.ink, opacity: 0.06),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: Material(
          color: Colors.transparent,
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
            title: Text(result.title, style: AppText.body),
            subtitle: Text(
              result.source,
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
            trailing: canAttach
                ? IconButton(
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 15),
                    tooltip: mealName == null
                        ? 'Attach to meal'
                        : 'Attach to $mealName',
                    onPressed: onAttach,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
