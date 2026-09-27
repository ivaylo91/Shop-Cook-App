import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../sharing/share_actions.dart';
import 'list_detail_screen.dart';

/// Screens at least this wide show the lists and the open list side by side.
/// Below it — every phone, and a tablet held upright — a list opens as a page
/// of its own.
const twoPaneMinWidth = 900.0;

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  /// The list open in the right-hand pane, when there is one.
  String? _selectedId;

  static const _listPaneWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < twoPaneMinWidth) {
      return _listsPane(context, ref, onOpen: null);
    }

    final palette = context.palette;
    final lists = ref.watch(_listsStreamProvider).valueOrNull ?? const [];
    // Follows the stream rather than a stored copy, so a rename shows in
    // the right-hand pane too; falls back to the newest when the chosen
    // list is deleted, or before anything has been chosen.
    final selected =
        lists.where((l) => l.id == _selectedId).firstOrNull ??
        lists.firstOrNull;

    return Row(
      children: [
        SizedBox(
          width: _listPaneWidth,
          child: _listsPane(
            context,
            ref,
            onOpen: (list) => setState(() => _selectedId = list.id),
            selectedId: selected?.id,
          ),
        ),
        VerticalDivider(width: 1, color: palette.divider),
        Expanded(
          child: selected == null
              ? const Scaffold(body: SizedBox.shrink())
              : ListDetailScreen(key: ValueKey(selected.id), list: selected),
        ),
      ],
    );
  }

  /// The lists themselves. [onOpen] replaces pushing a page when the list
  /// opens beside them instead.
  Widget _listsPane(
    BuildContext context,
    WidgetRef ref, {
    required void Function(ShoppingList list)? onOpen,
    String? selectedId,
  }) {
    final l10n = context.l10n;
    final listsAsync = ref.watch(_listsStreamProvider);

    final shared = ref.watch(sharedListsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLists),
        actions: [
          TextButton.icon(
            onPressed: () => joinSharedList(context, ref),
            icon: const FaIcon(FontAwesomeIcons.userPlus, size: 14),
            label: Text(l10n.joinAction),
          ),
          const SizedBox(width: Insets.sm),
        ],
      ),
      body: listsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: SkeletonRows(count: 3),
        ),
        error: (_, __) => ErrorState(
          title: l10n.listsLoadError,
          details: l10n.listsLoadErrorDetail,
          onRetry: () => ref.invalidate(_listsStreamProvider),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return EmptyState(
              icon: FontAwesomeIcons.rectangleList,
              title: l10n.listsEmptyTitle,
              message: l10n.listsEmptyMessage,
              actionLabel: l10n.listsEmptyAction,
              onAction: () => _createList(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.lg,
              Insets.lg,
              96,
            ),
            itemCount: lists.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
            itemBuilder: (context, index) {
              final list = lists[index];
              return Dismissible(
                key: ValueKey(list.id),
                direction: DismissDirection.endToStart,
                background: const _DeleteBackground(),
                // Deleting a list cascades to every meal, product and recipe
                // under it, so it both asks first and offers an undo.
                confirmDismiss: (_) => confirmAction(
                  context,
                  title: l10n.listsDeleteTitle(list.name),
                  message: shared.containsKey(list.id)
                      ? l10n.listsDeleteSharedMessage
                      : l10n.listsDeleteMessage,
                  confirmLabel: l10n.actionDelete,
                  destructive: true,
                ),
                onDismissed: (_) => _deleteWithUndo(context, ref, list),
                child: _ListCard(
                  list: list,
                  shared: shared.containsKey(list.id),
                  selected: list.id == selectedId,
                  onOpen: onOpen == null ? null : () => onOpen(list),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createList(context, ref),
        tooltip: l10n.listsNewTitle,
        child: const FaIcon(FontAwesomeIcons.plus, size: 18),
      ),
    );
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: context.l10n.listsNewTitle,
      hint: context.l10n.listsNewHint,
      confirmLabel: context.l10n.actionCreate,
    );
    if (name == null) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    await ref
        .read(shoppingListRepositoryProvider)
        .createList(name, userId: userId);
  }
}

/// Deletes the list but keeps its rows in hand, so the snackbar can put the
/// whole subtree back rather than only the list itself.
Future<void> _deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(shoppingListRepositoryProvider);

  // A shared list is taken out of sharing first. Best effort: offline, the
  // phone still forgets it, and the server copy stays with the others.
  final userId = ref.read(currentUserIdProvider);
  if (userId != null &&
      (ref.read(sharedListsProvider).valueOrNull?.containsKey(list.id) ??
          false)) {
    try {
      await ref.read(listSyncProvider).stopSharing(list.id, userId: userId);
    } catch (_) {}
  }

  final deleted = await repository.deleteListWithUndo(list.id);

  messenger.replaceSnackBar(
    SnackBar(
      content: Text(l10n.listsDeleted(list.name)),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l10n.actionUndo,
        onPressed: () => repository.undoDelete(deleted),
      ),
    ),
  );
}

/// One list, with how far through it you are.
class _ListCard extends ConsumerWidget {
  final ShoppingList list;

  /// Whether this is the list open beside the lists on a wide screen.
  final bool selected;

  /// Whether the list is shared with other people.
  final bool shared;

  /// Opens the list beside the lists; null pushes it as a page instead.
  final VoidCallback? onOpen;

  const _ListCard({
    required this.list,
    this.selected = false,
    this.shared = false,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = _card(context, ref);
    if (!selected) return card;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.accent, width: 2),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: card,
    );
  }

  Widget _card(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final products =
        ref.watch(_listProductsProvider(list.id)).valueOrNull ?? const [];
    final checked = products.where((p) => p.isChecked).length;
    final done = products.isNotEmpty && checked == products.length;

    return AppCard(
      padding: const EdgeInsets.all(Insets.lg),
      shadowOpacity: 0.07,
      onTap: onOpen ?? () => context.push('/list/${list.id}', extra: list),
      onLongPress: () => _actions(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Insets.sm),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(
                    alpha: palette.isDark ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: FaIcon(
                  done
                      ? FontAwesomeIcons.circleCheck
                      : FontAwesomeIcons.rectangleList,
                  size: 15,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  list.name,
                  style: AppText.title.copyWith(color: palette.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (shared) ...[
                Tooltip(
                  message: context.l10n.listShared,
                  child: FaIcon(
                    FontAwesomeIcons.userGroup,
                    size: 13,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: Insets.sm),
              ],
              if (products.isNotEmpty)
                CountPill(label: '$checked/${products.length}'),
              const SizedBox(width: Insets.xs),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 13,
                color: palette.inkFaint,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (products.isEmpty)
            Text(
              context.l10n.listCardEmpty,
              style: AppText.caption.copyWith(color: palette.inkMuted),
            )
          else ...[
            AppProgressBar(done: checked, total: products.length, height: 6),
            const SizedBox(height: Insets.sm),
            Text(
              done
                  ? context.l10n.listCardAllPicked
                  : context.l10n.listCardLeftToBuy(products.length - checked),
              style: AppText.caption.copyWith(color: palette.inkFaint),
            ),
          ],
        ],
      ),
    );
  }

  /// Rename, duplicate or delete, in a sheet — the same shape as a meal's.
  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;

    final action = await showAppSheet<String>(
      context: context,
      title: list.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.pen, size: 16),
            title: Text(l10n.actionRename),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.copy, size: 16),
            title: Text(l10n.listsDuplicate),
            subtitle: Text(l10n.listsDuplicateSubtitle),
            onTap: () => Navigator.pop(context, 'duplicate'),
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.trashCan, size: 16, color: error),
            title: Text(l10n.actionDelete, style: TextStyle(color: error)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'rename':
        await _rename(context, ref);
      case 'duplicate':
        await _duplicate(context, ref);
      case 'delete':
        final confirmed = await confirmAction(
          context,
          title: l10n.listsDeleteTitle(list.name),
          message: shared
              ? l10n.listsDeleteSharedMessage
              : l10n.listsDeleteMessage,
          confirmLabel: l10n.actionDelete,
          destructive: true,
        );
        if (confirmed && context.mounted) {
          await _deleteWithUndo(context, ref, list);
        }
    }
  }

  /// Copies the list under a new name, for next week's shop or a
  /// recurring occasion.
  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final name = await promptForText(
      context,
      title: l10n.listsDuplicateTitle,
      initialValue: l10n.listsCopyName(list.name),
      confirmLabel: l10n.actionCreate,
    );
    if (name == null || name.trim().isEmpty) return;

    await ref
        .read(shoppingListRepositoryProvider)
        .duplicateList(list.id, name: name.trim(), userId: userId);
    messenger.replaceSnackBar(
      SnackBar(content: Text(l10n.listsDuplicated(name.trim()))),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: context.l10n.listsRenameTitle,
      initialValue: list.name,
    );
    if (name == null) return;

    await ref.read(shoppingListRepositoryProvider).renameList(list.id, name);
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.actionDelete,
            style: AppText.caption.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: Insets.sm),
          FaIcon(
            FontAwesomeIcons.trashCan,
            size: 17,
            color: scheme.onErrorContainer,
          ),
        ],
      ),
    );
  }
}

final _listsStreamProvider = StreamProvider<List<ShoppingList>>((ref) async* {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    yield const [];
    return;
  }

  final repository = ref.watch(shoppingListRepositoryProvider);
  // Claim before reading, so a device upgrading from an ownerless schema
  // shows its existing lists rather than looking wiped.
  await repository.claimUnownedLists(userId);
  yield* repository.watchLists(userId);
});

final _listProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  listId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchAllProducts(listId);
});
