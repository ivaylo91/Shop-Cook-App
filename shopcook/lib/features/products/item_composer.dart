import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../barcode/barcode_scanner_screen.dart';
import '../barcode/product_lookup.dart';
import '../recipes/ingredient_parser.dart';
import '../voice/spoken_list.dart';
import '../voice/voice_capture.dart';

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

  /// Null takes the generic hint; screens with a narrower job pass their own.
  final String? hintText;

  const ItemComposer({
    super.key,
    required this.listId,
    this.mealId,
    this.hintText,
  });

  @override
  ConsumerState<ItemComposer> createState() => _ItemComposerState();
}

class _ItemComposerState extends ConsumerState<ItemComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  ParsedIngredient? _preview;
  bool _busy = false;

  /// A scanned code waiting for the name it will be remembered under.
  String? _pendingBarcode;

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
    // A scanned code belongs to what was typed after it, not to a tapped
    // suggestion; either way it is used up by this add.
    final barcode = raw == null ? _pendingBarcode : null;
    _pendingBarcode = null;

    final outcome = await ref
        .read(shoppingListRepositoryProvider)
        .addOrMergeProduct(
          listId: widget.listId,
          mealId: widget.mealId,
          name: parsed.name,
          quantity: parsed.quantity,
          unit: parsed.unit,
        );

    if (barcode != null) {
      await ref.read(productLookupProvider).remember(barcode, parsed.name);
    }

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
      final l10n = context.l10n;
      final name = outcome.name ?? '';
      ScaffoldMessenger.of(context).replaceSnackBar(
        SnackBar(
          content: Text(
            outcome.amount.isEmpty
                ? l10n.composerMergedPlain(name)
                : l10n.composerMergedAmount(name, outcome.amount),
          ),
        ),
      );
    }
  }

  void _fill(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }

  Future<void> _scan() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final language = Localizations.localeOf(context).languageCode;

    final code = await scanBarcode(context);
    if (code == null || !mounted) return;

    setState(() => _busy = true);
    final name = await ref
        .read(productLookupProvider)
        .nameFor(code, language: language);
    if (!mounted) return;
    setState(() => _busy = false);

    // Either way the name lands in the field rather than on the list, so a
    // wrong match can be fixed and an amount added before it is kept.
    _pendingBarcode = code;
    if (name != null) {
      _fill(name);
    } else {
      _fill('');
      messenger.replaceSnackBar(SnackBar(content: Text(l10n.scanUnknown)));
    }
  }

  Future<void> _dictate() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    _pendingBarcode = null;
    final spoken = await captureSpeech(context);
    if (spoken == null || !mounted) return;

    final items = splitSpokenList(spoken);
    if (items.isEmpty) return;
    if (items.length == 1) {
      _fill(items.single);
      return;
    }

    final chosen = await _confirmItems(items);
    if (chosen == null || chosen.isEmpty || !mounted) return;

    final repository = ref.read(shoppingListRepositoryProvider);
    for (final item in chosen) {
      final parsed = parseIngredient(item);
      if (parsed.name.isEmpty) continue;
      await repository.addOrMergeProduct(
        listId: widget.listId,
        mealId: widget.mealId,
        name: parsed.name,
        quantity: parsed.quantity,
        unit: parsed.unit,
      );
    }
    HapticFeedback.selectionClick();
    messenger.replaceSnackBar(
      SnackBar(content: Text(l10n.voiceAdded(chosen.length))),
    );
  }

  /// Several items heard at once: show them, each untickable, before adding.
  Future<List<String>?> _confirmItems(List<String> items) {
    final keep = {for (var i = 0; i < items.length; i++) i};
    return showAppSheet<List<String>>(
      context: context,
      title: context.l10n.voiceConfirmTitle,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      CheckboxListTile(
                        value: keep.contains(i),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(items[i]),
                        onChanged: (_) => setSheetState(
                          () => keep.contains(i) ? keep.remove(i) : keep.add(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: keep.isEmpty
                      ? null
                      : () => Navigator.pop(context, [
                          for (var i = 0; i < items.length; i++)
                            if (keep.contains(i)) items[i],
                        ]),
                  child: Text(context.l10n.voiceAddCount(keep.length)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    // With nothing typed, the ways in other than typing; once typing, add.
    final empty = _controller.text.trim().isEmpty && !_busy;

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
                        hintText:
                            widget.hintText ??
                            context.l10n.listDetailComposerHint,
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
                  if (empty) ...[
                    IconButton(
                      onPressed: _dictate,
                      tooltip: l10n.voiceTooltip,
                      icon: FaIcon(
                        FontAwesomeIcons.microphone,
                        size: 18,
                        color: palette.inkMuted,
                      ),
                    ),
                    IconButton(
                      onPressed: _scan,
                      tooltip: l10n.scanTooltip,
                      icon: FaIcon(
                        FontAwesomeIcons.barcode,
                        size: 18,
                        color: palette.inkMuted,
                      ),
                    ),
                  ] else
                  IconButton(
                    onPressed: _busy ? null : () => _submit(),
                    tooltip: context.l10n.composerAdd,
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

final productSuggestionsProvider = StreamProvider<List<ProductSuggestion>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(shoppingListRepositoryProvider).watchSuggestions(userId);
});
