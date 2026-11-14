import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../../shared/widgets/error_banner.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create your account', style: ZTypography.titleLg),
                    const SizedBox(height: ZSpacing.xs),
                    Text(
                      'Book rides or send goods anywhere in Bengaluru.',
                      style: ZTypography.body
                          .copyWith(color: ZColors.textSecondary),
                    ),
                    const SizedBox(height: ZSpacing.xxl),
                    if (auth.error != null) ...[
                      ZErrorBanner(message: auth.error!),
                      const SizedBox(height: ZSpacing.lg),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ZTextField(
                            controller: _firstName,
                            label: 'First name',
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: ZSpacing.md),
                        Expanded(
                          child: ZTextField(
                            controller: _lastName,
                            label: 'Last name',
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    ZTextField(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter your email';
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    ZTextField(
                      controller: _phone,
                      label: 'Phone (optional)',
                      hint: '+91 98xxx xxxxx',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    ZTextField(
                      controller: _password,
                      label: 'Password',
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline_rounded,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Create a password';
                        if (v.length < 6) return 'Use at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: ZSpacing.xl),
                    ZButton(
                      label: 'Create account',
                      loading: auth.busy,
                      onPressed: auth.busy ? null : _submit,
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    Text(
                      'By continuing you agree to Zuum’s Terms of Service '
                      'and Privacy Policy.',
                      style: ZTypography.caption
                          .copyWith(color: ZColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: ZSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Already have an account?',
                            style: ZTypography.body
                                .copyWith(color: ZColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Log in'),
                        ),
                      ],
                    ),
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
