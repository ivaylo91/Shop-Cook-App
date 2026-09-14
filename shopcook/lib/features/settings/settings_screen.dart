import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/brand/shopcook_logo.dart';
import '../../core/design.dart';
import '../../core/providers.dart';
import '../../core/settings.dart';
import '../../core/ui/ui.dart';

/// Appearance and account, in the place people look for them.
///
/// Theme mode used to live as an icon in the lists app bar because there was
/// nowhere else to put it; sign-out was the icon beside it. Neither belongs in
/// a screen about shopping lists.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final mode = ref.watch(themeModeProvider);
    final email = ref.watch(authRepositoryProvider).currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
            label: 'Appearance',
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
                      title: Text(_label(option)),
                      subtitle: option == ThemeMode.system
                          ? const Text('Follows your phone')
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
            icon: FontAwesomeIcons.user,
            label: 'Account',
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
                  email ?? 'Signed in',
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
                  'Your lists are stored on this device only. Signing in does '
                  'not sync them anywhere yet, so another phone will show an '
                  'empty app.',
                  style: AppText.caption.copyWith(color: palette.inkMuted),
                ),
                const SizedBox(height: Insets.lg),
                OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: const FaIcon(
                    FontAwesomeIcons.rightFromBracket,
                    size: 14,
                  ),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          SectionLabel(
            icon: FontAwesomeIcons.circleInfo,
            label: 'About',
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
                        'ShopCook',
                        style: AppText.body.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Shop for the week, cook what you planned.',
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

  String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Match phone',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
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
}
