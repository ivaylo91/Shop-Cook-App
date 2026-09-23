import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/brand/shopcook_logo.dart';
import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/settings.dart';
import '../../core/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import '../home_widget/home_widget_sync.dart';
import '../shopping/category_label.dart';

/// Appearance, language and account, in the place people look for them.
///
/// Theme mode used to live as an icon in the lists app bar because there was
/// nowhere else to put it; sign-out was the icon beside it. Neither belongs in
/// a screen about shopping lists.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final email = ref.watch(authRepositoryProvider).currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          Insets.xxl,
        ),
        children: [
          SectionLabel(
            icon: FontAwesomeIcons.circleHalfStroke,
            label: l10n.settingsAppearance,
            color: palette.accent,
          ),
          const SizedBox(height: Insets.md),
          AppCard(
            padding: const EdgeInsets.all(Insets.sm),
            shadowOpacity: 0.07,
            // The group's value and handler live on the ancestor now; the
            // per-tile groupValue/onChanged pair is deprecated.
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).set(value);
                }
              },
              child: Column(
                children: [
                  for (final option in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: option,
                      title: Text(_themeLabel(l10n, option)),
                      subtitle: option == ThemeMode.system
                          ? Text(l10n.themeSystemSubtitle)
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          SectionLabel(
            icon: FontAwesomeIcons.language,
            label: l10n.settingsLanguage,
            color: palette.accent,
          ),
          const SizedBox(height: Insets.md),
          AppCard(
            padding: const EdgeInsets.all(Insets.sm),
            shadowOpacity: 0.07,
            // Null means "follow the phone", which is the default: a Bulgarian
            // phone should open the app in Bulgarian without anyone choosing.
            child: RadioGroup<Locale?>(
              groupValue: locale,
              onChanged: (value) =>
                  ref.read(localeProvider.notifier).set(value),
              child: Column(
                children: [
                  RadioListTile<Locale?>(
                    value: null,
                    title: Text(l10n.languageSystem),
                    subtitle: Text(l10n.themeSystemSubtitle),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                    ),
                  ),
                  for (final option in supportedAppLocales)
                    RadioListTile<Locale?>(
                      value: option,
                      // Each language named in itself, so someone who has the
                      // app in a language they cannot read can still find the
                      // way out.
                      title: Text(localeEndonym(option)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          SectionLabel(
            icon: FontAwesomeIcons.arrowDownUpAcrossLine,
            label: l10n.settingsAisleOrder,
            color: palette.accent,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            l10n.settingsAisleOrderNote,
            style: AppText.caption.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: Insets.md),
          const _AisleOrderCard(),
          const SizedBox(height: Insets.xl),
          SectionLabel(
            icon: FontAwesomeIcons.user,
            label: l10n.settingsAccount,
            color: palette.inkMuted,
          ),
          const SizedBox(height: Insets.md),
          AppCard(
            padding: const EdgeInsets.all(Insets.lg),
            tint: palette.ink,
            shadowOpacity: 0.06,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email ?? l10n.settingsSignedIn,
                  style: AppText.body.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  // Being honest about this matters: someone who signs in on a
                  // new phone and finds it empty would otherwise assume the
                  // app lost their data.
                  l10n.settingsDeviceOnly,
                  style: AppText.caption.copyWith(color: palette.inkMuted),
                ),
                const SizedBox(height: Insets.lg),
                OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: const FaIcon(
                    FontAwesomeIcons.rightFromBracket,
                    size: 14,
                  ),
                  label: Text(l10n.settingsSignOut),
                ),
                const SizedBox(height: Insets.sm),
                const _DeleteAccountButton(),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          SectionLabel(
            icon: FontAwesomeIcons.circleInfo,
            label: l10n.settingsAbout,
            color: palette.inkMuted,
          ),
          const SizedBox(height: Insets.md),
          AppCard(
            padding: const EdgeInsets.all(Insets.lg),
            tint: palette.ink,
            shadowOpacity: 0.06,
            child: Row(
              children: [
                const ShopCookLogoBadge(size: 44),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: AppText.body.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.appTagline,
                        style: AppText.caption.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      };

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final email = ref.read(authRepositoryProvider).currentUser?.email;

    final confirmed = await confirmAction(
      context,
      title: l10n.settingsSignOutTitle,
      message: email == null
          ? l10n.settingsSignOutMessage
          : l10n.settingsSignOutMessageEmail(email),
      confirmLabel: l10n.settingsSignOut,
    );

    if (confirmed) {
      await clearHomeWidget();
      await ref.read(authRepositoryProvider).signOut();
      // The router redirect takes it from here.
    }
  }
}

/// Deleting the account, which Google Play requires any app with accounts
/// to offer from inside the app.
///
/// The progress shows in the button rather than in a dialog: deleting ends
/// the session, which sends the router to the login screen, and a dialog
/// still open at that moment took the new page down with it when it closed,
/// leaving a black screen.
class _DeleteAccountButton extends ConsumerStatefulWidget {
  const _DeleteAccountButton();

  @override
  ConsumerState<_DeleteAccountButton> createState() =>
      _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<_DeleteAccountButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authRepositoryProvider);
    final database = ref.read(databaseProvider);
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    final confirmed = await confirmAction(
      context,
      title: l10n.settingsDeleteAccountTitle,
      message: l10n.settingsDeleteAccountMessage,
      confirmLabel: l10n.settingsDeleteAccountConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    // The server first: if it fails, nothing on the phone has been touched.
    final deleted = await auth.deleteAccount();
    if (deleted) {
      await database.deleteUserData(userId);
      await clearHomeWidget();
    } else if (mounted) {
      setState(() => _busy = false);
    }
    messenger.replaceSnackBar(
      SnackBar(
        content: Text(
          deleted ? l10n.settingsAccountDeleted : l10n.settingsDeleteFailed,
        ),
      ),
    );
    // On success the session is gone and the router returns to login, which
    // takes this screen with it — so there is no state left to reset.
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return TextButton.icon(
      onPressed: _busy ? null : _delete,
      style: TextButton.styleFrom(foregroundColor: error),
      icon: _busy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: error),
            )
          : const FaIcon(FontAwesomeIcons.userXmark, size: 14),
      label: Text(context.l10n.settingsDeleteAccount),
    );
  }
}

/// The nine aisles, draggable into the order of the reader's own shop.
class _AisleOrderCard extends ConsumerWidget {
  const _AisleOrderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final order = ref.watch(aisleOrderProvider);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      shadowOpacity: 0.07,
      child: Column(
        children: [
          ReorderableListView(
            shrinkWrap: true,
            // The card scrolls with the page; a nested scroll view would
            // fight it for the drag.
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // onReorderItem rather than the deprecated onReorder: it hands
            // back a newIndex already adjusted for the removed item, so the
            // controller must not adjust it a second time.
            onReorderItem: (oldIndex, newIndex) => ref
                .read(aisleOrderProvider.notifier)
                .reorder(oldIndex, newIndex),
            children: [
              for (final (index, category) in order.indexed)
                ListTile(
                  key: ValueKey(category.name),
                  leading: FaIcon(
                    category.icon,
                    size: 16,
                    color: palette.aisle(category),
                  ),
                  title: Text(category.label(l10n)),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: FaIcon(
                      FontAwesomeIcons.gripLines,
                      size: 15,
                      color: palette.inkFaint,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                  ),
                ),
            ],
          ),
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(
                right: Insets.sm,
                top: Insets.xs,
              ),
              child: TextButton(
                onPressed: () =>
                    ref.read(aisleOrderProvider.notifier).reset(),
                child: Text(l10n.settingsAisleOrderReset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
