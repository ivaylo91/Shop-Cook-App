import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/localization.dart';

/// The persistent bottom navigation.
///
/// Everything used to be a push stack off the lists screen, so the only way
/// between areas was back. Each branch keeps its own navigation state, which
/// is what an indexed stack buys over swapping bodies: scrolling the plan
/// and coming back to lists does not reset either.
///
/// Detail screens deliberately sit *outside* this shell and cover it — a list
/// detail already has a composer pinned to its bottom edge, and a nav bar
/// under that would fight it for the thumb.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;

  const AppShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // goBranch with initialLocation resets a branch when its tab is
        // tapped while already selected, which is the expected "take me to
        // the top" behaviour.
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        backgroundColor: palette.card,
        indicatorColor: palette.accent.withValues(
          alpha: palette.isDark ? 0.24 : 0.14,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        destinations: [
          NavigationDestination(
            icon: const FaIcon(FontAwesomeIcons.rectangleList, size: 18),
            label: context.l10n.navLists,
          ),
          NavigationDestination(
            icon: const FaIcon(FontAwesomeIcons.calendarDays, size: 18),
            label: context.l10n.navPlan,
          ),
          NavigationDestination(
            icon: const FaIcon(FontAwesomeIcons.gear, size: 18),
            label: context.l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
