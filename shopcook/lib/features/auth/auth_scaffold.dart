import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    return Scaffold(
      backgroundColor: AppColors.surface,
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
                  Text(title, style: AppText.display.copyWith(fontSize: 26)),
                  const SizedBox(height: Insets.sm),
                  Text(
                    subtitle,
                    style: AppText.body.copyWith(color: AppColors.inkMuted),
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
        Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: const FaIcon(
            FontAwesomeIcons.basketShopping,
            size: 20,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: Insets.md),
        Text('ShopCook', style: AppText.title),
      ],
    );
  }
}

/// Email and password fields share enough behaviour to be worth one widget.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
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
          prefixIcon: Icon(icon, size: 16),
          // Keep the show/hide toggle tappable, but out of the tab order:
          // pressing "Next" on the password field should reach the next
          // field, not the eye button. ExcludeFocus rather than
          // Focus(skipTraversal:) because IconButton builds its own focus
          // node underneath, which a skipped parent does not cover.
          suffixIcon: suffix == null ? null : ExcludeFocus(child: suffix!),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
        ),
      ),
    );
  }
}
