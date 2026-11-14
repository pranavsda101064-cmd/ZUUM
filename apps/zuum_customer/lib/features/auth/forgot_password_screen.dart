import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../../shared/widgets/error_banner.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(_email.text.trim());
    if (mounted && ref.read(authControllerProvider).error == null) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: ZColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: ZSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent ? _sentView() : _formView(auth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formView(AuthState auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reset password', style: ZTypography.titleLg),
          const SizedBox(height: ZSpacing.xs),
          Text(
            'Enter your email and we’ll send you a reset link.',
            style: ZTypography.body.copyWith(color: ZColors.textSecondary),
          ),
          const SizedBox(height: ZSpacing.xxl),
          if (auth.error != null) ...[
            ZErrorBanner(message: auth.error!),
            const SizedBox(height: ZSpacing.lg),
          ],
          ZTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.mail_outline_rounded,
            onFieldSubmitted: (_) => _submit(),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter your email';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: ZSpacing.xl),
          ZButton(
            label: 'Send reset link',
            loading: auth.busy,
            onPressed: auth.busy ? null : _submit,
          ),
          const SizedBox(height: ZSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to log in'),
          ),
        ],
      ),
    );
  }

  Widget _sentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: ZColors.successTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: ZColors.success, size: 28),
        ),
        const SizedBox(height: ZSpacing.xl),
        Text('Check your email',
            style: ZTypography.titleLg, textAlign: TextAlign.center),
        const SizedBox(height: ZSpacing.sm),
        Text(
          'If an account exists for ${_email.text.trim()}, a reset link is on its way.',
          style: ZTypography.body.copyWith(color: ZColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZSpacing.xxl),
        ZButton(
          label: 'Back to log in',
          variant: ZButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
