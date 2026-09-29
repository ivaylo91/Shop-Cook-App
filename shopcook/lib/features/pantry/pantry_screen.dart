import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';

/// Things the user has at home. Recipe imports and the week's shop leave
/// these off, so the olive oil in the cupboard is not bought again because
/// a recipe mentioned it.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    final userId = ref.read(currentUserIdProvider);
    if (name.isEmpty || userId == null) return;
    await ref.read(databaseProvider).addToPantry(userId, name);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final items = ref.watch(pantryProvider).valueOrNull ?? const [];

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l10n.pantryTitle)),
        body: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              shadowOpacity: 0.07,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        hintText: l10n.pantryAddHint,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _add,
                    tooltip: l10n.actionAdd,
                    icon: FaIcon(
                      FontAwesomeIcons.circlePlus,
                      size: 20,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            if (items.isEmpty)
              InlineNote(message: l10n.pantryEmptyMessage)
            else
              AppCardList(
                tint: palette.accent,
                children: [
                  for (final item in items)
                    ListTile(
                      leading: FaIcon(
                        FontAwesomeIcons.house,
                        size: 14,
                        color: palette.accent,
                      ),
                      title: Text(item.name),
                      trailing: IconButton(
                        tooltip: l10n.actionRemove,
                        icon: FaIcon(
                          FontAwesomeIcons.xmark,
                          size: 15,
                          color: palette.inkMuted,
                        ),
                        onPressed: () => ref
                            .read(databaseProvider)
                            .removeFromPantry(item.userId, item.key),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// What the signed-in user has at home.
final pantryProvider = StreamProvider<List<PantryItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(databaseProvider).watchPantry(userId);
});
