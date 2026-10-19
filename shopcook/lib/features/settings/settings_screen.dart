import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/shopcook_logo.dart';
import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/settings.dart';
import '../../core/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import '../home_widget/home_widget_sync.dart';
import '../notifications/push.dart';
import '../onboarding/intro.dart';
import '../pantry/pantry_screen.dart';
import '../sharing/share_actions.dart';
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
    final pantry = ref.watch(pantryProvider).valueOrNull?.length ?? 0;

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ScreenHeader(title: l10n.navSettings),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Insets.lg, 6, Insets.lg, 110),
          children: [
            const _ProfileCard(),
            const SizedBox(height: Insets.md),
            _Group(
              title: l10n.settingsAppearance,
              child: Row(
                children: [
                  for (final (i, option) in ThemeMode.values.indexed) ...[
                    if (i > 0) const SizedBox(width: Insets.sm),
                    Expanded(
                      child: _ThemeTile(
                        label: _themeLabel(l10n, option),
                        icon: switch (option) {
                          ThemeMode.system => FontAwesomeIcons.mobileScreen,
                          ThemeMode.light => FontAwesomeIcons.sun,
                          ThemeMode.dark => FontAwesomeIcons.moon,
                        },
                        selected: mode == option,
                        onTap: () =>
                            ref.read(themeModeProvider.notifier).set(option),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            _Group(
              title: l10n.settingsLanguage,
              // Null means "follow the phone", which is the default: a
              // Bulgarian phone should open the app in Bulgarian without
              // anyone choosing.
              child: Column(
                children: [
                  _ChoiceRow(
                    title: l10n.languageSystem,
                    subtitle: l10n.themeSystemSubtitle,
                    selected: locale == null,
                    onTap: () => ref.read(localeProvider.notifier).set(null),
                  ),
                  for (final option in supportedAppLocales)
                    _ChoiceRow(
                      // Each language named in itself, so someone who has
                      // the app in a language they cannot read can still
                      // find the way out.
                      title: localeEndonym(option),
                      selected: locale == option,
                      onTap: () =>
                          ref.read(localeProvider.notifier).set(option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.sm,
              ),
              shadowOpacity: 0.07,
              child: Column(
                children: [
                  _LinkRow(
                    icon: FontAwesomeIcons.arrowDownUpAcrossLine,
                    tile: const Color(0xFFE2EEFB),
                    tint: const Color(0xFF2C5E95),
                    title: l10n.settingsAisleOrder,
                    subtitle: l10n.settingsAisleOrderSubtitle,
                    onTap: () => showAppSheet<void>(
                      context: context,
                      title: l10n.settingsAisleOrder,
                      subtitle: l10n.settingsAisleOrderNote,
                      builder: (context) => const _AisleOrderCard(),
                    ),
                  ),
                  _LinkRow(
                    icon: FontAwesomeIcons.house,
                    tile: const Color(0xFFFFEBD6),
                    tint: const Color(0xFFA9520F),
                    title: l10n.pantryTitle,
                    subtitle: '${l10n.pantryCount(pantry)} · ${l10n.pantryNote}',
                    onTap: () => context.push('/pantry'),
                  ),
                  _LinkRow(
                    icon: FontAwesomeIcons.circlePlay,
                    tile: const Color(0xFFDFF2E5),
                    tint: const Color(0xFF2F7A45),
                    title: l10n.settingsShowIntro,
                    subtitle: l10n.appTagline,
                    onTap: () => showIntro(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context, ref),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: palette.accent,
                      backgroundColor: palette.floating,
                      side: BorderSide(color: palette.accent, width: 1.5),
                      textStyle: AppText.body.copyWith(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const FaIcon(
                      FontAwesomeIcons.rightFromBracket,
                      size: 15,
                    ),
                    label: Text(l10n.settingsSignOut),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                const Expanded(child: _DeleteAccountButton()),
              ],
            ),
            const SizedBox(height: Insets.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShopCookLogoBadge(size: 28),
                const SizedBox(width: Insets.sm),
                Text(
                  l10n.appTitle,
                  style: AppText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
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
      // While still signed in: the server lets an account remove only its
      // own phone.
      await unregisterPush();
      await ref.read(authRepositoryProvider).signOut();
      // The router redirect takes it from here.
    }
  }
}

/// Who is signed in, the name others see in shared lists, and where the
/// lists are kept.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final name = ref.watch(displayNameProvider).trim();
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';
    final initial = (name.isNotEmpty ? name : email).characters.firstOrNull;

    return AppCard(
      padding: const EdgeInsets.all(Insets.lg),
      shadowOpacity: 0.07,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2FA77A), Color(0xFF17805B)],
                  ),
                ),
                child: initial == null
                    ? const FaIcon(
                        FontAwesomeIcons.user,
                        size: 20,
                        color: Color(0xFFFFFFFF),
                      )
                    : Text(
                        initial.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? l10n.settingsYourNameNotSet : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    Text(
                      email.isEmpty ? l10n.settingsSignedIn : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => askDisplayName(context, ref),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                  textStyle: AppText.caption.copyWith(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(l10n.settingsEdit),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.accent.withValues(
                alpha: palette.isDark ? 0.18 : 0.13,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(
                  FontAwesomeIcons.shieldHalved,
                  size: 15,
                  color: palette.heroInk,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // Being honest about this matters: someone who signs in
                    // on a new phone and finds it empty would otherwise
                    // assume the app lost their data.
                    l10n.settingsDeviceOnly,
                    style: AppText.caption.copyWith(
                      fontSize: 12,
                      height: 1.45,
                      color: palette.heroInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with a small heading over its contents.
class _Group extends StatelessWidget {
  final String title;
  final Widget child;

  const _Group({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 14, Insets.lg, Insets.md),
      shadowOpacity: 0.07,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppText.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.palette.ink,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// One of the three looks, as a tile with its icon.
class _ThemeTile extends StatelessWidget {
  final String label;
  final FaIconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = selected ? palette.heroInk : palette.ink;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: palette.isDark ? 0.16 : 0.07)
            : palette.sunken.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? palette.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(icon, size: 20, color: fg),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Tick(size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round green tick: the chosen one.
class _Tick extends StatelessWidget {
  final double size;

  const _Tick({required this.size});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: palette.accent),
      child: FaIcon(
        FontAwesomeIcons.check,
        size: size * 0.5,
        color: palette.onAccent,
      ),
    );
  }
}

/// A row in a single-choice list, with a round tick at its end.
class _ChoiceRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.chip),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppText.caption.copyWith(
                            fontSize: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.md),
                if (selected)
                  const _Tick(size: 24)
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.divider, width: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that leads somewhere, behind a pastel icon tile.
class _LinkRow extends StatelessWidget {
  final FaIconData icon;
  final Color tile;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.tile,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.chip),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? Color.alphaBlend(
                          tint.withValues(alpha: 0.3),
                          palette.card,
                        )
                      : tile,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(
                  icon,
                  size: 17,
                  color: palette.isDark ? palette.ink : tint,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 13,
                color: palette.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
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
      style: TextButton.styleFrom(
        foregroundColor: error,
        minimumSize: const Size.fromHeight(50),
        textStyle: AppText.body.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  leading: Illustration(Art.of(category), size: 34),
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
              padding: const EdgeInsets.only(right: Insets.sm, top: Insets.xs),
              child: TextButton(
                onPressed: () => ref.read(aisleOrderProvider.notifier).reset(),
                child: Text(l10n.settingsAisleOrderReset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
