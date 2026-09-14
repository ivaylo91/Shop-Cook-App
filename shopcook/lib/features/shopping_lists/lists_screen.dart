import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
import '../../core/settings.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(_listsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopCook'),
        actions: [
          const _ThemeModeButton(),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18),
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
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
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return Dismissible(
                key: ValueKey(list.id),
                direction: DismissDirection.endToStart,
                background: const _DeleteBackground(),
                // Deleting a list cascades to every meal, product and recipe
                // under it, so it asks first. Undo arrives with the
                // soft-delete column in the next phase.
                confirmDismiss: (_) => confirmAction(
                  context,
                  title: 'Delete "${list.name}"?',
                  message: 'This also removes its meals, items and recipes. '
                      'That cannot be undone yet.',
                  confirmLabel: 'Delete',
                  destructive: true,
                ),
                onDismissed: (_) => ref
                    .read(shoppingListRepositoryProvider)
                    .deleteList(list.id),
                child: ListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.rectangleList,
                    size: 20,
                  ),
                  title: Text(list.name),
                  subtitle: _ListProgress(listId: list.id),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () => context.push('/list/${list.id}', extra: list),
                ),
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

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final email = ref.read(authRepositoryProvider).currentUser?.email;

    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message: email == null
          ? 'You will need to sign in again to get back in.'
          : 'You are signed in as $email. You will need to sign in again to '
                'get back in.',
      confirmLabel: 'Sign out',
    );

    if (confirmed) {
      await ref.read(authRepositoryProvider).signOut();
      // The router redirect takes it from here.
    }
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final name = await promptForText(
      context,
      title: 'New shopping list',
      hint: 'e.g. Weekly groceries',
      confirmLabel: 'Create',
    );
    if (name == null) return;

    await ref.read(shoppingListRepositoryProvider).createList(name);
  }
}

/// Light, dark, or whatever the phone is set to.
///
/// Lives in the app bar until there is a settings screen to hold it; a theme
/// nobody can reach is not a feature.
class _ThemeModeButton extends ConsumerWidget {
  const _ThemeModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Appearance',
      icon: FaIcon(_iconFor(mode), size: 17),
      initialValue: mode,
      onSelected: (value) => ref.read(themeModeProvider.notifier).set(value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: ThemeMode.system, child: Text('Match phone')),
        PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
        PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
      ],
    );
  }

  FaIconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => FontAwesomeIcons.circleHalfStroke,
    ThemeMode.light => FontAwesomeIcons.sun,
    ThemeMode.dark => FontAwesomeIcons.moon,
  };
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

/// Shopping progress for one list, e.g. "2 of 5 checked".
class _ListProgress extends ConsumerWidget {
  final String listId;

  const _ListProgress({required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products =
        ref.watch(_listProductsProvider(listId)).valueOrNull ?? const [];
    if (products.isEmpty) return const Text('Empty');

    final checked = products.where((p) => p.isChecked).length;
    return Text('$checked of ${products.length} checked');
  }
}

final _listsStreamProvider = StreamProvider<List<ShoppingList>>((ref) {
  return ref.watch(shoppingListRepositoryProvider).watchLists();
});

final _listProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  listId,
) {
  return ref.watch(shoppingListRepositoryProvider).watchAllProducts(listId);
});
