import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../design.dart';

/// One checkable item: a name, an optional detail line, and a tick.
///
/// Deliberately typed to plain strings rather than to a Drift row, so the
/// same row renders a shopping-mode item, a meal ingredient and an unassigned
/// product without three near-copies of this layout.
///
/// The whole row is the tap target, and the tick is confirmed with a haptic:
/// on a phone held one-handed in a shop, that tick is most of the feedback
/// the user gets.
class ProductRow extends StatelessWidget {
  final String name;

  /// Quantity, unit, which meal wants it — whatever explains why the item is
  /// on the list. Already joined by the caller.
  final String? details;
  final bool checked;
  final ValueChanged<bool> onToggle;

  /// Overflow affordances. Prefer a swipe or a long-press sheet at the call
  /// site; this is for the cases that genuinely need a visible control.
  final Widget? trailing;
  final VoidCallback? onLongPress;

  const ProductRow({
    super.key,
    required this.name,
    required this.checked,
    required this.onToggle,
    this.details,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final detail = details?.trim() ?? '';

    return MergeSemantics(
      child: Semantics(
        checked: checked,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(!checked);
          },
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.sm,
              Insets.xs,
              Insets.sm,
              Insets.xs,
            ),
            child: Row(
              children: [
                CheckDot(checked: checked),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: Motion.base,
                        curve: Motion.enter,
                        style: AppText.title.copyWith(
                          color: checked ? palette.inkFaint : palette.ink,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: palette.inkFaint,
                        ),
                        child: Text(name),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: AppText.caption.copyWith(
                            color: checked
                                ? palette.inkFaint
                                : palette.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null) const SizedBox(width: Insets.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44×44 tap target around a 26px dot, so it stays hittable one-handed.
///
/// Ticked dots are always the accent green rather than the aisle colour:
/// "green means picked up" should mean the same thing everywhere.
class CheckDot extends StatelessWidget {
  final bool checked;

  const CheckDot({super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.enter,
          width: 26,
          height: 26,
          // FaIcon renders a bare RichText with no box of its own — unlike
          // Material's Icon, which centres its glyph internally. Without an
          // alignment here the tick gets tight 26x26 constraints and lays
          // out top-left, hanging out of the circle.
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: checked ? palette.accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: checked
                  ? palette.accent
                  : palette.ink.withValues(alpha: 0.22),
              width: 2,
            ),
          ),
          child: checked
              ? FaIcon(
                  FontAwesomeIcons.check,
                  size: 13,
                  color: palette.onAccent,
                )
              : null,
        ),
      ),
    );
  }
}
