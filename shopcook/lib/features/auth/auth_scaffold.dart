import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/brand/shopcook_logo.dart';
import '../../core/design.dart';

/// Shared frame for the sign in and register screens, so the two feel like
/// one flow rather than two separately built pages.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.xl),
            child: ConstrainedBox(
              // Long lines are hard to read; keep the form column narrow
              // even on a tablet.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Brand(),
                  const SizedBox(height: Insets.xxl),
                  Text(
                    title,
                    style: AppText.display.copyWith(
                      fontSize: 26,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    subtitle,
                    style: AppText.body.copyWith(color: palette.inkMuted),
                  ),
                  const SizedBox(height: Insets.xl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ShopCookLogoBadge(size: 52),
        const SizedBox(width: Insets.md),
        Text(
          'ShopCook',
          style: AppText.title.copyWith(color: context.palette.ink),
        ),
      ],
    );
  }
}

/// Email and password fields share enough behaviour to be worth one widget.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final FaIconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final String? errorText;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  /// Lets the screen clear a stale error the moment the user starts fixing
  /// it, rather than leaving "Enter your email" under a filled-in field.
  final VoidCallback? onChanged;
  final Widget? suffix;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autocorrect: false,
        enableSuggestions: !obscure,
        onChanged: (_) => onChanged?.call(),
        onSubmitted: (_) => onSubmitted?.call(),
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          // Centred explicitly: InputDecoration drops the prefix icon into a
          // 48x48 minimum box, and FaIcon has no box of its own to centre
          // within it, so a bare FaIcon sits hard against the left edge.
          prefixIcon: SizedBox(
            width: 48,
            child: Center(child: FaIcon(icon, size: 15)),
          ),
          // Keep the show/hide toggle tappable, but out of the tab order:
          // pressing "Next" on the password field should reach the next
          // field, not the eye button. ExcludeFocus rather than
          // Focus(skipTraversal:) because IconButton builds its own focus
          // node underneath, which a skipped parent does not cover.
          suffixIcon: suffix == null ? null : ExcludeFocus(child: suffix!),
          // Fill, border and radius now come from the theme's
          // inputDecorationTheme, so every field in the app matches without
          // each one restating it.
        ),
      ),
    );
  }
}
