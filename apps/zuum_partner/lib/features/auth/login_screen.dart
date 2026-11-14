import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../../shared/widgets/error_banner.dart';

class PartnerLoginScreen extends ConsumerStatefulWidget {
  const PartnerLoginScreen({super.key});

  @override
  ConsumerState<PartnerLoginScreen> createState() =>
      _PartnerLoginScreenState();
}

class _PartnerLoginScreenState extends ConsumerState<PartnerLoginScreen> {
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
    await ref.read(partnerAuthProvider.notifier).login(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(partnerAuthProvider);
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
                    const ZBrandMark(),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ZColors.highlight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'PARTNER',
                          style: ZTypography.overline.copyWith(
                            color: ZColors.dark,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    Text(
                      'ಸುಸ್ವಾಗತ',
                      style: ZTypography.kannada(
                        fontSize: 13,
                        color: ZColors.primary,
                      ),
                    ),
                    const SizedBox(height: ZSpacing.xs),
                    Text('Partner sign in', style: ZTypography.titleLg),
                    const SizedBox(height: ZSpacing.xs),
                    Text(
                      'Sign in to start earning across Bengaluru.',
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
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: ZSpacing.xxl),
                    ZButton(
                      label: 'Sign in',
                      loading: auth.busy,
                      onPressed: auth.busy ? null : _submit,
                    ),
                    const SizedBox(height: ZSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'New to Zuum Partner?',
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
