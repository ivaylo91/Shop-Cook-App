import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Catch the obvious mistakes locally rather than spending a round trip
  /// to be told the email is blank.
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
      _passwordError = password.isEmpty ? l10n.authEnterPassword : null;
      _formError = null;
    });

    return _emailError == null && _passwordError == null;
  }

  /// Clear a stale error as soon as the user starts correcting it.
  void _clearErrors() {
    if (_emailError == null && _passwordError == null && _formError == null) {
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
      _formError = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    setState(() => _busy = true);

    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email: _email.text, password: _password.text);

    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _busy = false;
      _formError = switch (result.outcome) {
        AuthOutcome.offline => l10n.authNetworkError,
        // Supabase answers in English whatever the phone's language is;
        // showing its wording beats inventing a vaguer local one.
        AuthOutcome.rejected => result.serverMessage,
        _ => null,
      };
    });
    // On success the router's redirect moves us to the lists screen.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
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
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
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
        if (_formError != null) ...[
          _FormError(message: _formError!),
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
              : Text(l10n.loginSubmit),
        ),
        const SizedBox(height: Insets.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.loginNoAccount,
              style: AppText.body.copyWith(color: context.palette.inkMuted),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.push('/register'),
              child: Text(l10n.loginCreateOne),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormError extends StatelessWidget {
  final String message;

  const _FormError({required this.message});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
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
          FaIcon(FontAwesomeIcons.circleExclamation, size: 15, color: color),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(message, style: AppText.caption.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
