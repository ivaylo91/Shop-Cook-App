import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/providers.dart';
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
              decoration: const InputDecoration(labelText: 'Title'),
            ),
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Search YouTube & the web',
                      prefixIcon: Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
                      border: OutlineInputBorder(),
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
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_loading && _searched && _results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No live results. This usually means the search API keys '
              "haven't been configured on the backend yet.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _attachManualLink,
              icon: const FaIcon(FontAwesomeIcons.link, size: 18),
              label: const Text('Attach a link manually instead'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        return ListTile(
          leading: r.thumbnailUrl.isEmpty
              ? Icon(
                  r.type == RecipeResultType.video
                      ? FontAwesomeIcons.play
                      : FontAwesomeIcons.fileLines,
                )
              : Image.network(
                  r.thumbnailUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const FaIcon(FontAwesomeIcons.image, size: 18),
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
