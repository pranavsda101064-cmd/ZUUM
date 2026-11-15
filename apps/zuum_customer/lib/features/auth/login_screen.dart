import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../../shared/widgets/error_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).login(
          email: _email.text.trim(),
          password: _password.text,
        );
    // Success → router redirect sends us to /home; failure → error in state.
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
                    const ZPhotoHero(
                      photo: 'blr_aerial_dusk',
                      height: 160,
                      caption: 'BENGALURU · NAMMA CITY',
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    const ZBrandMark(),
                    const SizedBox(height: ZSpacing.md),
                    Text(
                      'ಸುಸ್ವಾಗತ',
                      style: ZTypography.kannada(
                        fontSize: 13,
                        color: ZColors.primary,
                      ),
                    ),
                    const SizedBox(height: ZSpacing.xs),
                    Text('Welcome back', style: ZTypography.titleLg),
                    const SizedBox(height: ZSpacing.xs),
                    Text(
                      'Log in to book rides and deliveries across Bengaluru.',
                      style: ZTypography.body
                          .copyWith(color: ZColors.textSecondary),
                    ),
                    const SizedBox(height: ZSpacing.xxl),
                    if (auth.error != null) ...[
                      ZErrorBanner(message: auth.error!),
                      const SizedBox(height: ZSpacing.lg),
                    ],
                    ZTextField(
                      controller: _email,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline_rounded,
                      autofillHints: const [AutofillHints.email],
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
                      controller: _password,
                      label: 'Password',
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline_rounded,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your password';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: ZSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/auth/forgot'),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: ZSpacing.sm),
                    ZButton(
                      label: 'Log in',
                      loading: auth.busy,
                      onPressed: auth.busy ? null : _submit,
                    ),
                    const SizedBox(height: ZSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'New to Zuum?',
                            style: ZTypography.body
                                .copyWith(color: ZColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/auth/register'),
                          child: const Text('Create account'),
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
