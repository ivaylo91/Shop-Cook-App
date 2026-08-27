import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/providers.dart';
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
          IconButton(
            icon: const FaIcon(
              FontAwesomeIcons.rightFromBracket,
              size: 18,
            ),
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lists) {
          if (lists.isEmpty) {
            return const Center(
              child: Text('No shopping lists yet. Tap + to create one.'),
            );
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return Dismissible(
                key: ValueKey(list.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const FaIcon(FontAwesomeIcons.trashCan, size: 18),
                ),
                onDismissed: (_) => ref
                    .read(shoppingListRepositoryProvider)
                    .deleteList(list.id),
                child: ListTile(
                  leading: const FaIcon(FontAwesomeIcons.rectangleList, size: 20),
                  title: Text(list.name),
                  subtitle: _ListProgress(listId: list.id),
                  trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
                  onTap: () => context.push('/list/${list.id}', extra: list),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createList(context, ref),
        child: const FaIcon(FontAwesomeIcons.plus, size: 18),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final email = ref.read(authRepositoryProvider).currentUser?.email;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          email == null
              ? 'You will need to sign in again to get back in.'
              : 'You are signed in as $email. You will need to sign in '
                    'again to get back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authRepositoryProvider).signOut();
      // The router redirect takes it from here.
    }
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New shopping list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Weekly groceries'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(shoppingListRepositoryProvider).createList(name.trim());
    }
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
