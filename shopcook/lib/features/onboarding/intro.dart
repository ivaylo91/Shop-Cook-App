import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/settings.dart';
import '../../core/ui/ui.dart';

const _seenKey = 'introSeen';

/// Shows the tour once, to someone opening the app with nothing in it yet.
///
/// A new user lands on an empty Lists screen, and nothing on it says that
/// meals, recipes, cooking mode or sharing exist. Someone who already has
/// lists — a tester updating, say — has found their way and is not shown
/// it; they are only marked as having seen it.
class IntroGate extends ConsumerStatefulWidget {
  final Widget child;

  const IntroGate({super.key, required this.child});

  @override
  ConsumerState<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends ConsumerState<IntroGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences.getBool(_seenKey) ?? false) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final lists = await ref
        .read(shoppingListRepositoryProvider)
        .watchLists(userId)
        .first;
    await preferences.setBool(_seenKey, true);
    if (lists.isNotEmpty || !mounted) return;

    await showIntro(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The tour, full screen. Also reachable from Settings.
Future<void> showIntro(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => const _Intro(),
    ),
  );
}

class _Intro extends StatefulWidget {
  const _Intro();

  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next(int count) {
    if (_page == count - 1) {
      Navigator.of(context).pop();
      return;
    }
    if (context.reduceMotion) {
      _pages.jumpToPage(_page + 1);
    } else {
      _pages.nextPage(duration: Motion.base, curve: Motion.enter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final steps = [
      (
        icon: FontAwesomeIcons.cartShopping,
        title: l10n.introShopTitle,
        body: l10n.introShopBody,
      ),
      (
        icon: FontAwesomeIcons.utensils,
        title: l10n.introCookTitle,
        body: l10n.introCookBody,
      ),
      (
        icon: FontAwesomeIcons.userGroup,
        title: l10n.introShareTitle,
        body: l10n.introShareBody,
      ),
    ];
    final last = _page == steps.length - 1;

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.sm),
                  // Kept in the layout on the last page so nothing shifts;
                  // there it would only duplicate the button below.
                  child: Visibility(
                    visible: !last,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.introSkip),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    for (final step in steps)
                      _Step(
                        icon: step.icon,
                        title: step.title,
                        body: step.body,
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    AnimatedContainer(
                      duration: Motion.fast,
                      curve: Motion.enter,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? palette.accent
                            : palette.accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(Insets.xl),
                child: SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    child: FilledButton(
                      onPressed: () => _next(steps.length),
                      child: Text(last ? l10n.introStart : l10n.introNext),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final FaIconData icon;
  final String title;
  final String body;

  const _Step({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(Insets.xxl),
            decoration: BoxDecoration(
              color: palette.wash(palette.accent, palette.isDark ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, size: 44, color: palette.accent),
          ),
          const SizedBox(height: Insets.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.display.copyWith(color: palette.ink, fontSize: 26),
          ),
          const SizedBox(height: Insets.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: palette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
