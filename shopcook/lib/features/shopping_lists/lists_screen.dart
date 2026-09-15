import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(_listsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lists')),
      body: listsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: SkeletonRows(count: 3),
        ),
        error: (_, __) => ErrorState(
          title: 'Could not load your lists',
          details: 'Your lists are stored on this device, so this is usually '
              'temporary.',
          onRetry: () => ref.invalidate(_listsStreamProvider),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return EmptyState(
              icon: FontAwesomeIcons.rectangleList,
              title: 'No shopping lists yet',
              message: 'A list holds the meals you are cooking and everything '
                  'you need to buy for them.',
              actionLabel: 'Create a list',
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
                  title: 'Delete "${list.name}"?',
                  message:
                      'This also removes its meals, items and recipes. You '
                      'can undo it straight afterwards.',
                  confirmLabel: 'Delete',
                  destructive: true,
                ),
                onDismissed: (_) => _deleteWithUndo(context, ref, list),
                child: _ListCard(list: list),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createList(context, ref),
        tooltip: 'New shopping list',
        child: const FaIcon(FontAwesomeIcons.plus, size: 18),
      ),
    );
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: 'New shopping list',
      hint: 'e.g. Weekly groceries',
      confirmLabel: 'Create',
    );
    if (name == null) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    await ref
        .read(shoppingListRepositoryProvider)
        .createList(name, userId: userId);
  }

  /// Deletes the list but keeps its rows in hand, so the snackbar can put the
  /// whole subtree back rather than only the list itself.
  Future<void> _deleteWithUndo(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(shoppingListRepositoryProvider);
    final deleted = await repository.deleteListWithUndo(list.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${list.name}"'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repository.undoDelete(deleted),
        ),
      ),
    );
  }
}

/// One list, with how far through it you are.
class _ListCard extends ConsumerWidget {
  final ShoppingList list;

  const _ListCard({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final products =
        ref.watch(_listProductsProvider(list.id)).valueOrNull ?? const [];
    final checked = products.where((p) => p.isChecked).length;
    final done = products.isNotEmpty && checked == products.length;

    return AppCard(
      padding: const EdgeInsets.all(Insets.lg),
      shadowOpacity: 0.07,
      onTap: () => context.push('/list/${list.id}', extra: list),
      onLongPress: () => _rename(context, ref),
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
              'Empty — open it to add meals and items.',
              style: AppText.caption.copyWith(color: palette.inkMuted),
            )
          else ...[
            AppProgressBar(done: checked, total: products.length, height: 6),
            const SizedBox(height: Insets.sm),
            Text(
              done
                  ? 'Everything picked up'
                  : '${products.length - checked} left to buy',
              style: AppText.caption.copyWith(color: palette.inkFaint),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: 'Rename list',
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
            'Delete',
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
