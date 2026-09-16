import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_scaffold.dart';

/// Supabase rejects anything shorter, so say it up front rather than
/// bouncing the user off the server.
const _minPasswordLength = 6;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = context.l10n;
    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      _emailError = email.isEmpty
          ? l10n.authEnterEmail
          : (!email.contains('@') || !email.contains('.'))
          ? l10n.authInvalidEmail
          : null;
      _passwordError = password.isEmpty
          ? l10n.authChoosePassword
          : password.length < _minPasswordLength
          ? l10n.authPasswordTooShort(_minPasswordLength)
          : null;
      _confirmError = _confirm.text != password
          ? l10n.authPasswordsDiffer
          : null;
      _formError = null;
    });

    return _emailError == null &&
        _passwordError == null &&
        _confirmError == null;
  }

  /// Clear a stale error as soon as the user starts correcting it.
  void _clearErrors() {
    if (_emailError == null &&
        _passwordError == null &&
        _confirmError == null &&
        _formError == null) {
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _formError = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    setState(() {
      _busy = true;
      _notice = null;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .signUp(email: _email.text, password: _password.text);

    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _busy = false;
      _formError = switch (result.outcome) {
        AuthOutcome.offline => l10n.authNetworkError,
        AuthOutcome.rejected => result.serverMessage,
        _ => null,
      };
      _notice = result.needsEmailConfirmation ? l10n.authCheckInbox : null;
    });
    // A successful sign-up with a session is picked up by the router.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      children: [
        AuthField(
          controller: _email,
          label: l10n.authEmail,
          icon: FontAwesomeIcons.envelope,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: _clearErrors,
        ),
        AuthField(
          controller: _password,
          label: l10n.authPassword,
          icon: FontAwesomeIcons.lock,
          obscure: !_showPassword,
          errorText: _passwordError,
          onChanged: _clearErrors,
          suffix: IconButton(
            icon: FaIcon(
              _showPassword ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
              size: 15,
            ),
            tooltip: _showPassword
                ? l10n.authHidePassword
                : l10n.authShowPassword,
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        AuthField(
          controller: _confirm,
          label: l10n.authConfirmPassword,
          icon: FontAwesomeIcons.lock,
          obscure: !_showPassword,
          errorText: _confirmError,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          onChanged: _clearErrors,
        ),
        if (_formError != null) ...[
          _Banner(
            message: _formError!,
            color: Theme.of(context).colorScheme.error,
            icon: FontAwesomeIcons.circleExclamation,
          ),
          const SizedBox(height: Insets.lg),
        ],
        if (_notice != null) ...[
          _Banner(
            message: _notice!,
            color: context.palette.accent,
            icon: FontAwesomeIcons.envelopeCircleCheck,
          ),
          const SizedBox(height: Insets.lg),
        ],
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.palette.onAccent,
                  ),
                )
              : Text(l10n.registerSubmit),
        ),
        const SizedBox(height: Insets.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.registerHaveAccount,
              style: AppText.body.copyWith(color: context.palette.inkMuted),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => context.canPop()
                        ? context.pop()
                        : context.go('/login'),
              child: Text(l10n.loginSubmit),
            ),
          ],
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final Color color;
  final FaIconData icon;

  const _Banner({
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 15, color: color),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(message, style: AppText.caption.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
