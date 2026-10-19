import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/brand/shopcook_logo.dart';
import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/settings.dart';
import '../../core/ui/ui.dart';

/// Shared frame for the sign in and register screens, so the two feel like
/// one flow rather than two separately built pages.
///
/// The brand and a language switch along the top, a two-line headline, the
/// basket on a soft glow, then the form on a glass card, and under it the
/// way to the other screen.
class AuthScaffold extends StatelessWidget {
  final String title;

  /// A first line over [title], in green: "Shop smart." over "Cook happy."
  final String? accentTitle;
  final String subtitle;

  /// The form: fields, any error, and the submit button. On the card.
  final List<Widget> form;

  /// Under the card: the way to the other screen.
  final List<Widget> below;

  /// Shown at the very bottom, quieter than the rest: the copyright line.
  final Widget? footer;

  const AuthScaffold({
    super.key,
    required this.title,
    this.accentTitle,
    required this.subtitle,
    required this.form,
    this.below = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final headline = AppText.display.copyWith(
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: palette.ink,
    );

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                Insets.lg,
              ),
              child: ConstrainedBox(
                // Long lines are hard to read; keep the form column narrow
                // even on a tablet.
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Brand(),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                if (accentTitle != null)
                                  TextSpan(
                                    text: '$accentTitle\n',
                                    style: TextStyle(color: palette.accent),
                                  ),
                                TextSpan(text: title),
                              ],
                            ),
                            style: headline,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: AppText.body.copyWith(
                              color: palette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    Center(
                      child: Container(
                        width: 230,
                        height: 150,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(75),
                          gradient: RadialGradient(
                            center: const Alignment(0, 0.2),
                            colors: [
                              const Color(
                                0xFFFFFFFF,
                              ).withValues(alpha: palette.isDark ? 0.08 : 1),
                              const Color(0x00FFFFFF),
                            ],
                            stops: const [0, 0.7],
                          ),
                        ),
                        child: const Illustration(Art.basket, size: 150),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Container(
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: BoxDecoration(
                        color: palette.glass,
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(color: palette.glassEdge),
                        boxShadow: palette.shadow(
                          palette.accent,
                          opacity: 0.08,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: form,
                      ),
                    ),
                    if (below.isNotEmpty) ...[
                      const SizedBox(height: Insets.md),
                      ...below,
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: Insets.lg),
                      footer!,
                    ],
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

class _Brand extends ConsumerWidget {
  const _Brand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final current = Localizations.localeOf(context).languageCode;

    return Row(
      children: [
        const ShopCookLogoBadge(size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.l10n.appTitle,
            style: AppText.title.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
        ),
        // The language, switchable before signing in: someone handed a
        // phone set to the other language should not have to find
        // Settings first.
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: palette.floating,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final locale in supportedAppLocales.reversed)
                _LanguageChip(
                  code: locale.languageCode == 'bg' ? 'БГ' : 'EN',
                  name: localeEndonym(locale),
                  selected: locale.languageCode == current,
                  onTap: () => ref.read(localeProvider.notifier).set(locale),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String code;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.code,
    required this.name,
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
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 36,
            constraints: const BoxConstraints(minWidth: 50),
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            alignment: Alignment.center,
            child: Text(
              code,
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? palette.onAccent : palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The form's main button: its label at the start and an arrow in a
/// circle at the end, or a spinner while it works.
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PressScale(
      child: FilledButton(
        // Kept green while it works; the spinner says it is busy.
        onPressed: busy ? () {} : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.only(left: Insets.xl, right: Insets.sm),
          textStyle: AppText.body.copyWith(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.onAccent.withValues(alpha: 0.22),
              ),
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.onAccent,
                      ),
                    )
                  : FaIcon(
                      FontAwesomeIcons.arrowRight,
                      size: 16,
                      color: palette.onAccent,
                    ),
            ),
          ],
        ),
      ),
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

  static OutlineInputBorder _well(Color ring) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: ring == Colors.transparent
        ? BorderSide.none
        : BorderSide(color: ring, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
          // A recessed well inside the card, rather than a white field on
          // white: no rim at rest, the accent ring only while typing.
          filled: true,
          fillColor: palette.isDark ? palette.sunken : const Color(0xFFF4F7F4),
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          border: _well(Colors.transparent),
          enabledBorder: _well(Colors.transparent),
          focusedBorder: _well(palette.accent),
          errorBorder: _well(Theme.of(context).colorScheme.error),
          focusedErrorBorder: _well(Theme.of(context).colorScheme.error),
          // A placeholder inside the field, not a label that floats up onto
          // the border: with the icon beside it there is no doubt which
          // field is which, and the floating label cut a gap into the ring.
          hintText: label,
          errorText: errorText,
          // Centred explicitly: FaIcon has no box of its own to centre
          // within, so a bare FaIcon sits hard against the left edge. The
          // box is narrower than InputDecoration's 48 dp default, which left
          // a wide gap between the icon and the text.
          prefixIcon: SizedBox(
            width: 44,
            child: Center(child: FaIcon(icon, size: 15)),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
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
