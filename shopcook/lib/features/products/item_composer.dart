import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../recipes/ingredient_parser.dart';

/// One field that adds an item, pinned to the bottom of a list.
///
/// Replaces the three-field modal that used to sit behind a floating button.
/// Adding an item is the most frequent thing anyone does in this app, and a
/// dialog made it the slowest: tap the button, wait for the dialog, fill three
/// fields, confirm, repeat.
///
/// The text runs through [parseIngredient] — the same parser that splits
/// recipe imports — so "2 kg potatoes" fills name, quantity and unit from one
/// line. The parse is shown before it is committed, because guessing wrong
/// silently would be worse than not guessing.
class ItemComposer extends ConsumerStatefulWidget {
  final String listId;

  /// The meal this adds to, or null to add loose to the list.
  final String? mealId;

  final String hintText;

  const ItemComposer({
    super.key,
    required this.listId,
    this.mealId,
    this.hintText = 'Add an item — try "2 kg potatoes"',
  });

  @override
  ConsumerState<ItemComposer> createState() => _ItemComposerState();
}

class _ItemComposerState extends ConsumerState<ItemComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  ParsedIngredient? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = _controller.text.trim();
    final parsed = text.isEmpty ? null : parseIngredient(text);

    // Only worth showing when the parser actually split something off;
    // echoing "Milk -> Milk" is noise.
    final interesting =
        parsed != null &&
        (parsed.quantity.isNotEmpty ||
            parsed.unit.isNotEmpty ||
            parsed.name.toLowerCase() != text.toLowerCase());

    setState(() => _preview = interesting ? parsed : null);
  }

  Future<void> _submit([String? raw]) async {
    final text = (raw ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;

    setState(() => _busy = true);
    final parsed = parseIngredient(text);

    final outcome = await ref
        .read(shoppingListRepositoryProvider)
        .addOrMergeProduct(
          listId: widget.listId,
          mealId: widget.mealId,
          name: parsed.name,
          quantity: parsed.quantity,
          unit: parsed.unit,
        );

    if (!mounted) return;

    _controller.clear();
    setState(() {
      _busy = false;
      _preview = null;
    });

    // Keep the caret where it was so a weekly shop can be typed straight
    // through without reaching for the field again.
    _focus.requestFocus();
    HapticFeedback.selectionClick();

    if (outcome.didMerge) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.mergeMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Suggestions(
              query: _controller.text,
              onPick: (name) => _submit(name),
            ),
            if (_preview != null) _ParsePreview(parsed: _preview!),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.sm,
                Insets.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: Insets.md,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _submit(),
                    tooltip: 'Add',
                    icon: _busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.accent,
                            ),
                          )
                        : FaIcon(
                            FontAwesomeIcons.circlePlus,
                            size: 20,
                            color: palette.accent,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the parser made of the line, before it is committed.
class _ParsePreview extends StatelessWidget {
  final ParsedIngredient parsed;

  const _ParsePreview({required this.parsed});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = '${parsed.quantity} ${parsed.unit}'.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, 0),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.wandMagicSparkles,
            size: 11,
            color: palette.inkFaint,
          ),
          const SizedBox(width: Insets.sm),
          if (amount.isNotEmpty) ...[
            _Chip(label: amount, tint: palette.accent),
            const SizedBox(width: Insets.xs),
          ],
          Expanded(
            child: Text(
              parsed.name,
              style: AppText.caption.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color tint;

  const _Chip({required this.label, required this.tint});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: palette.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: tint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Names already typed before, ranked by how often.
///
/// A weekly shop is mostly the same things, so the fastest add is usually one
/// tap on something bought before rather than typing it again.
class _Suggestions extends ConsumerWidget {
  final String query;
  final ValueChanged<String> onPick;

  const _Suggestions({required this.query, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final all = ref.watch(productSuggestionsProvider).valueOrNull ?? const [];
    if (all.isEmpty) return const SizedBox.shrink();

    final needle = query.trim().toLowerCase();
    final matches = needle.isEmpty
        ? all
        : all
              .where((s) => s.name.toLowerCase().contains(needle))
              // An exact match is already typed; suggesting it adds nothing.
              .where((s) => s.name.toLowerCase() != needle)
              .toList();

    if (matches.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, 0),
        itemCount: matches.length.clamp(0, 12),
        separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
        itemBuilder: (context, index) {
          final suggestion = matches[index];
          return ActionChip(
            label: Text(suggestion.name),
            labelStyle: AppText.caption.copyWith(color: palette.ink),
            backgroundColor: palette.sunken,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            onPressed: () => onPick(suggestion.name),
          );
        },
      ),
    );
  }
}

final productSuggestionsProvider =
    StreamProvider<List<ProductSuggestion>>((ref) {
      return ref.watch(shoppingListRepositoryProvider).watchSuggestions();
    });
