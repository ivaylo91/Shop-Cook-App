import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/ui/ui.dart';
import '../home_widget/home_widget_sync.dart';

/// The floating bottom bar: four tabs on a frosted pill, and in the middle
/// a raised round Shop button with how many items are left.
///
/// The Shop button goes straight to shopping mode for the list with the
/// most left to buy (the same list the home screen widget shows). That is
/// the one thing people open the app for in a shop, so it gets the thumb's
/// best spot. With no lists yet it opens the Lists tab instead.
class AppNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final tabs = [
      (FontAwesomeIcons.rectangleList, l10n.navLists),
      (FontAwesomeIcons.calendarDays, l10n.navPlan),
      (FontAwesomeIcons.bookOpen, l10n.navRecipes),
      (FontAwesomeIcons.gear, l10n.navSettings),
    ];

    Widget tab(int index) => Expanded(
      child: _Tab(
        icon: tabs[index].$1,
        label: tabs[index].$2,
        selected: currentIndex == index,
        onTap: () => onSelect(index),
      ),
    );

    // The strip behind the floating bar continues the page's ground, which
    // runs from cream at the bottom left to peach at the bottom right.
    final ground = palette.ground;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ground.colors[1], ground.colors[2]]),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, bottom + 10),
        child: SizedBox(
          height: 66,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.glass,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.glassEdge),
              boxShadow: palette.shadow(palette.accent, opacity: 0.14),
            ),
            child: Row(
              children: [tab(0), tab(1), const _ShopButton(), tab(2), tab(3)],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.accent : palette.inkFaint;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected && !context.reduceMotion ? 1.1 : 1,
              duration: Motion.base,
              curve: Motion.enter,
              child: FaIcon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised centre button: shopping mode for the busiest list.
class _ShopButton extends ConsumerWidget {
  const _ShopButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final snapshot = ref.watch(widgetSnapshotProvider);
    final list = snapshot?.list;
    final left = snapshot?.left ?? 0;

    return SizedBox(
      width: 72,
      child: OverflowBox(
        maxHeight: 90,
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: const Offset(0, -16),
          child: Semantics(
            button: true,
            label: context.l10n.navShop,
            excludeSemantics: true,
            child: PressScale(
              child: GestureDetector(
                onTap: () => list == null
                    ? context.go('/lists')
                    : context.push('/list/${list.id}/shop', extra: list),
                child: Stack(
                  // Centred in the slot: the slot is wider than the circle.
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.accent,
                        border: Border.all(
                          color: palette.isDark
                              ? palette.surface
                              : const Color(0xFFFFFFFF),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.cartShopping,
                          size: 20,
                          color: palette.onAccent,
                        ),
                      ),
                    ),
                    if (left > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEE6A3F),
                            borderRadius: BorderRadius.circular(Radii.pill),
                            border: Border.all(
                              color: const Color(0xFFFFFFFF),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            left > 99 ? '99+' : '$left',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFFFFF),
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
