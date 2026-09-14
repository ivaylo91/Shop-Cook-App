import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/remote/recipe_search_api.dart';

class RecipeSearchScreen extends ConsumerStatefulWidget {
  final Meal meal;

  const RecipeSearchScreen({super.key, required this.meal});

  @override
  ConsumerState<RecipeSearchScreen> createState() =>
      _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends ConsumerState<RecipeSearchScreen> {
  late final TextEditingController _controller;
  List<RecipeSearchResult> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.meal.name);
    _runSearch(widget.meal.name);
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    final results = await ref.read(recipeRepositoryProvider).search(query.trim());
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _attachManualLink() async {
    final urlController = TextEditingController();
    final titleController = TextEditingController(text: widget.meal.name);
    final url = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach a link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: urlController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'YouTube or recipe URL',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'url': urlController.text.trim(),
            }),
            child: const Text('Attach'),
          ),
        ],
      ),
    );
    if (url == null || url['url']!.isEmpty) return;
    final isVideo =
        url['url']!.contains('youtube.com') || url['url']!.contains('youtu.be');
    await ref.read(recipeRepositoryProvider).attachRecipe(
          mealId: widget.meal.id,
          title: url['title']!.isEmpty ? url['url']! : url['title']!,
          sourceUrl: url['url']!,
          sourceType:
              isVideo ? RecipeSourceType.video : RecipeSourceType.web,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a recipe')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Search YouTube & the web',
                      prefixIcon: Icon(
                        FontAwesomeIcons.magnifyingGlass,
                        size: 16,
                      ),
                    ),
                    onSubmitted: _runSearch,
                  ),
                ),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.link, size: 18),
                  tooltip: 'Attach a link manually',
                  onPressed: _attachManualLink,
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Insets.lg),
        child: SkeletonRows(count: 4),
      );
    }

    if (_searched && _results.isEmpty) {
      return EmptyState(
        icon: Icons.travel_explore_outlined,
        title: 'No live results',
        message: 'This usually means the search API keys have not been set on '
            'the backend yet. You can still paste a link yourself.',
        actionLabel: 'Attach a link instead',
        actionIcon: Icons.link_rounded,
        onAction: _attachManualLink,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        return ListTile(
          leading: r.thumbnailUrl.isEmpty
              ? FaIcon(
                  r.type == RecipeResultType.video
                      ? FontAwesomeIcons.play
                      : FontAwesomeIcons.fileLines,
                  size: 18,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.chip),
                  child: Image.network(
                    r.thumbnailUrl,
                    width: 72,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const FaIcon(FontAwesomeIcons.image, size: 18),
                  ),
                ),
          title: Text(r.title),
          subtitle: Text(r.source),
          onTap: () async {
            await ref
                .read(recipeRepositoryProvider)
                .attachFromSearchResult(widget.meal.id, r);
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }
}
