import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../design.dart';
import 'press_scale.dart';

/// A round 44 dp button floating on the ground: back, search, plan.
///
/// White and nearly opaque, so it reads as something to press rather than
/// as part of the page behind it.
class RoundIconButton extends StatelessWidget {
  final FaIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: PressScale(
          child: Material(
            color: palette.floating,
            shape: const CircleBorder(),
            shadowColor: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: palette.shadow(palette.accent, opacity: 0.08),
                ),
                child: FaIcon(icon, size: 17, color: palette.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top of a tab or a detail page: a centred title between round
/// buttons, in place of a Material app bar.
///
/// The two sides are kept the same width, so the title stays centred on
/// the screen whatever sits either side of it.
class ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> leading;
  final List<Widget> trailing;

  /// Shows a back button first when the page was pushed.
  final bool back;

  const ScreenHeader({
    super.key,
    required this.title,
    this.leading = const [],
    this.trailing = const [],
    this.back = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final start = [
      if (back)
        RoundIconButton(
          icon: FontAwesomeIcons.chevronLeft,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
        ),
      ...leading,
    ];
    final sides = start.length > trailing.length
        ? start.length
        : trailing.length;
    final sideWidth = sides * 44.0 + (sides > 1 ? (sides - 1) * Insets.sm : 0);

    Widget side(List<Widget> buttons, MainAxisAlignment align) => SizedBox(
      width: sideWidth,
      child: Row(
        mainAxisAlignment: align,
        children: [
          for (final (i, b) in buttons.indexed) ...[
            if (i > 0) const SizedBox(width: Insets.sm),
            b,
          ],
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          Insets.xs,
        ),
        child: Row(
          children: [
            side(start, MainAxisAlignment.start),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            side(trailing, MainAxisAlignment.end),
          ],
        ),
      ),
    );
  }
}
