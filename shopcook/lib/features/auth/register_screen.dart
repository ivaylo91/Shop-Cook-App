import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/providers.dart';
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
    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!email.contains('@') || !email.contains('.'))
          ? 'That does not look like an email'
          : null;
      _passwordError = password.isEmpty
          ? 'Choose a password'
          : password.length < _minPasswordLength
          ? 'Use at least $_minPasswordLength characters'
          : null;
      _confirmError = _confirm.text != password
          ? 'Passwords do not match'
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
    setState(() {
      _busy = false;
      _formError = result.success ? null : result.message;
      _notice = result.needsEmailConfirmation ? result.message : null;
    });
    // A successful sign-up with a session is picked up by the router.
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'So your lists are tied to you, not just this phone.',
      children: [
        AuthField(
          controller: _email,
          label: 'Email',
          icon: FontAwesomeIcons.envelope,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: _clearErrors,
        ),
        AuthField(
          controller: _password,
          label: 'Password',
          icon: FontAwesomeIcons.lock,
          obscure: !_showPassword,
          errorText: _passwordError,
          onChanged: _clearErrors,
          suffix: IconButton(
            icon: FaIcon(
              _showPassword ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
              size: 15,
            ),
            tooltip: _showPassword ? 'Hide password' : 'Show password',
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        AuthField(
          controller: _confirm,
          label: 'Confirm password',
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
            color: AppColors.accent,
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
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create account'),
        ),
        const SizedBox(height: Insets.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have one?',
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => context.canPop()
                        ? context.pop()
                        : context.go('/login'),
              child: const Text('Sign in'),
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
  final IconData icon;

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
