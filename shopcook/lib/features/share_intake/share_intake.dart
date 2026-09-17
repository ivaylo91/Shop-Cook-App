import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../recipes/ingredient_parser.dart';
import '../recipes/library_screen.dart';
import 'shared_content.dart';

const _channel = MethodChannel('shopcook/share');

/// Index of the Recipes tab in the shell.
const _recipesTab = 2;

/// Picks up "Share → ShopCook" from other apps. Lives in the tab shell, so
/// it only acts once someone is signed in and there is somewhere to put
/// what was shared.
class ShareIntake extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;
  final Widget child;

  const ShareIntake({super.key, required this.shell, required this.child});

  @override
  ConsumerState<ShareIntake> createState() => _ShareIntakeState();
}

class _ShareIntakeState extends ConsumerState<ShareIntake> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await _pull();
    });
    // A share that launched the app is already waiting.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pull());
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _pull() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final Map<String, String?>? raw;
      try {
        raw = await _channel.invokeMapMethod<String, String?>('takeShared');
      } on MissingPluginException {
        return; // Not Android (or a test): nothing is ever shared in.
      }
      if (raw == null || !mounted) return;

      final content = parseShared(raw['text'] ?? '', subject: raw['subject']);
      switch (content) {
        case null:
          ScaffoldMessenger.of(context).replaceSnackBar(
            SnackBar(content: Text(context.l10n.shareNothingUsable)),
          );
        case SharedLink(:final url, :final title):
          widget.shell.goBranch(_recipesTab);
          // goBranch only schedules the navigation. A dialog opened now sits
          // on whatever page is on top (a list, say), and is thrown away with
          // it when the router swaps the pages a frame later.
          await WidgetsBinding.instance.endOfFrame;
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          await addLinkToLibrary(
            context,
            ref,
            initialUrl: url,
            initialTitle: title,
          );
        case SharedItems(:final lines):
          await _addItems(lines);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _addItems(List<String> lines) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(shoppingListRepositoryProvider);
    final lists = await repository.watchLists(userId).first;
    if (!mounted) return;
    if (lists.isEmpty) {
      messenger.replaceSnackBar(SnackBar(content: Text(l10n.shareNoLists)));
      return;
    }

    final list = await showAppSheet<ShoppingList>(
      context: context,
      title: l10n.shareAddItemsTitle(lines.length),
      // Show what is about to be added, so a stray share is obvious.
      subtitle: lines.take(4).join(', ') + (lines.length > 4 ? '…' : ''),
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in lists)
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.rectangleList, size: 16),
                title: Text(option.name),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (list == null) return;

    var added = 0;
    for (final line in lines) {
      final parsed = parseIngredient(line);
      if (parsed.name.isEmpty) continue;
      await repository.addOrMergeProduct(
        listId: list.id,
        name: parsed.name,
        quantity: parsed.quantity,
        unit: parsed.unit,
        userId: userId,
      );
      added++;
    }

    messenger.replaceSnackBar(
      SnackBar(
        content: Text(l10n.shareItemsAdded(added, list.name)),
        action: SnackBarAction(
          label: l10n.shareOpenList,
          onPressed: () => router.push('/list/${list.id}', extra: list),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
