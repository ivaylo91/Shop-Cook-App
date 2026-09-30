import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/settings.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import 'package:go_router/go_router.dart';

import '../shopping_lists/share_list.dart';
import '../notifications/push.dart';
import 'invite_link.dart';

/// The list's share button: send a copy as text, or share the list itself
/// so both people see and change the same one.
Future<void> showShareActions(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final l10n = context.l10n;
  final error = Theme.of(context).colorScheme.error;
  final shared = ref.read(sharedListsProvider).valueOrNull ?? const {};
  final isShared = shared.containsKey(list.id);
  final isOwner = shared[list.id] ?? false;

  final action = await showAppSheet<String>(
    context: context,
    title: list.name,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const FaIcon(FontAwesomeIcons.userGroup, size: 16),
          title: Text(isShared ? l10n.shareInvite : l10n.shareWithSomeone),
          subtitle: isShared ? null : Text(l10n.shareWithSomeoneSubtitle),
          onTap: () => Navigator.pop(context, 'invite'),
        ),
        ListTile(
          leading: const FaIcon(FontAwesomeIcons.message, size: 16),
          title: Text(l10n.shareAsText),
          subtitle: Text(l10n.shareAsTextSubtitle),
          onTap: () => Navigator.pop(context, 'text'),
        ),
        if (isShared)
          ListTile(
            leading: FaIcon(FontAwesomeIcons.linkSlash, size: 16, color: error),
            title: Text(
              isOwner ? l10n.shareStop : l10n.shareLeave,
              style: TextStyle(color: error),
            ),
            onTap: () => Navigator.pop(context, 'stop'),
          ),
      ],
    ),
  );

  if (action == null || !context.mounted) return;
  switch (action) {
    case 'text':
      final products = await ref
          .read(shoppingListRepositoryProvider)
          .watchAllProducts(list.id)
          .first;
      if (!context.mounted) return;
      await shareList(
        context,
        list: list,
        products: products,
        aisleOrder: ref.read(aisleOrderProvider),
      );
    case 'invite':
      await _invite(context, ref, list);
    case 'stop':
      await _stop(context, ref, list, isOwner: isOwner);
  }
}

/// Asks for the user's name when they have none yet. Cancelling carries on
/// without one; the others then see "Someone".
Future<void> ensureDisplayName(BuildContext context, WidgetRef ref) async {
  if (ref.read(displayNameProvider).isNotEmpty) return;
  await askDisplayName(context, ref);
}

/// The name prompt, from the share flow or Settings.
Future<void> askDisplayName(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final name = await promptForText(
    context,
    title: l10n.nameAskTitle,
    hint: l10n.nameHint,
    initialValue: ref.read(displayNameProvider),
  );
  if (name == null) return;
  await ref.read(displayNameProvider.notifier).set(name);
  ref.read(listSyncProvider).displayName = ref.read(displayNameProvider);
}

Future<void> _invite(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  await ensureDisplayName(context, ref);
  if (!context.mounted) return;

  final String code;
  try {
    code = await ref.read(listSyncProvider).share(list);
  } catch (_) {
    messenger.replaceSnackBar(SnackBar(content: Text(l10n.shareOffline)));
    return;
  }
  // The list is shared now, so there is something to be notified about.
  await askForNotifications(ref);
  if (!context.mounted) return;

  await showAppDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.shareInviteTitle(list.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shareInviteMessage),
          const SizedBox(height: Insets.lg),
          Center(
            child: SelectableText(
              // Read aloud or typed from another screen, so in two halves.
              '${code.substring(0, 4)} ${code.substring(4)}',
              style: AppText.title.copyWith(
                fontSize: 30,
                letterSpacing: 4,
                color: context.palette.accent,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.pop(context);
          },
          child: Text(MaterialLocalizations.of(context).copyButtonLabel),
        ),
        PressScale(
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              SharePlus.instance.share(
                ShareParams(
                  text: l10n.shareInviteText(list.name, inviteLink(code), code),
                ),
              );
            },
            icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 14),
            label: Text(l10n.shareInviteSend),
          ),
        ),
      ],
    ),
  );
}

Future<void> _stop(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list, {
  required bool isOwner,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  final confirmed = await confirmAction(
    context,
    title: isOwner ? l10n.shareStop : l10n.shareLeave,
    message: isOwner ? l10n.shareStopMessage : l10n.shareLeaveMessage,
    confirmLabel: isOwner ? l10n.shareStop : l10n.shareLeave,
    destructive: true,
  );
  if (!confirmed) return;

  try {
    await ref.read(listSyncProvider).stopSharing(list.id, userId: userId);
    messenger.replaceSnackBar(SnackBar(content: Text(l10n.shareStopped)));
  } catch (_) {
    messenger.replaceSnackBar(SnackBar(content: Text(l10n.shareOffline)));
  }
}

/// Asks for an invite code and joins the list it belongs to.
Future<void> joinSharedList(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final code = await promptForText(
    context,
    title: l10n.joinTitle,
    hint: l10n.joinHint,
    confirmLabel: l10n.joinAction,
  );
  if (code == null || !context.mounted) return;
  await joinWithCode(context, ref, code);
}

/// Joins the list behind [raw] and opens it. [ask] confirms first, for a
/// code that arrived by link rather than being typed: a tap on a link in a
/// chat should not silently add a list.
Future<void> joinWithCode(
  BuildContext context,
  WidgetRef ref,
  String raw, {
  bool ask = false,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final userId = ref.read(currentUserIdProvider);
  final code = cleanInviteCode(raw);
  if (userId == null || code == null) return;

  if (ask) {
    final confirmed = await confirmAction(
      context,
      title: l10n.joinTitle,
      message: l10n.joinConfirmMessage(code),
      confirmLabel: l10n.joinAction,
    );
    if (!confirmed || !context.mounted) return;
  }
  await ensureDisplayName(context, ref);

  try {
    final listId = await ref.read(listSyncProvider).join(code, userId: userId);
    if (listId == null) {
      messenger.replaceSnackBar(SnackBar(content: Text(l10n.joinBadCode)));
      return;
    }
    final list = await ref.read(databaseProvider).listById(listId);
    if (list == null) return;
    messenger.replaceSnackBar(SnackBar(content: Text(l10n.joined(list.name))));
    router.push('/list/${list.id}', extra: list);
    await askForNotifications(ref);
  } catch (_) {
    messenger.replaceSnackBar(SnackBar(content: Text(l10n.shareOffline)));
  }
}
