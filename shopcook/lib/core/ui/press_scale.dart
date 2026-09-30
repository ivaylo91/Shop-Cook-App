import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../design.dart';

/// Makes a button give slightly while it is pressed.
///
/// Material's ripple says "touched here"; the scale says "this moved under
/// your finger", which is what makes a control feel physical. Cards do the
/// same through their own ink (see `AppCard`); this is for buttons, whose
/// shape the theme cannot scale.
///
/// A disabled button does not give: nothing will happen, and it should not
/// look as though something did.
class PressScale extends StatefulWidget {
  final Widget child;

  const PressScale({super.key, required this.child});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  static const _pressedScale = 0.97;

  bool _pressed = false;
  Offset? _downAt;

  bool get _enabled => switch (widget.child) {
    ButtonStyleButton(:final enabled) => enabled,
    FloatingActionButton(:final onPressed) => onPressed != null,
    _ => true,
  };

  void _set(bool pressed) {
    if (pressed != _pressed && mounted) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;

    // Raw pointer events rather than a tap recogniser: a second recogniser
    // would compete with the button's own and one of them would lose.
    return Listener(
      onPointerDown: (event) {
        if (!_enabled) return;
        _downAt = event.position;
        _set(true);
      },
      // A finger that travels is scrolling, not pressing.
      onPointerMove: (event) {
        final down = _downAt;
        if (down != null && (event.position - down).distance > kTouchSlop) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? _pressedScale : 1,
        duration: Motion.fast,
        curve: Motion.enter,
        child: widget.child,
      ),
    );
  }
}
