import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../../shared/widgets/error_banner.dart';

class PartnerRegisterScreen extends ConsumerStatefulWidget {
  const PartnerRegisterScreen({super.key});

  @override
  ConsumerState<PartnerRegisterScreen> createState() =>
      _PartnerRegisterScreenState();
}

class _PartnerRegisterScreenState extends ConsumerState<PartnerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(partnerAuthProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
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
                    Text('Join Zuum Partner', style: ZTypography.titleLg),
                    const SizedBox(height: ZSpacing.xs),
                    Text(
                      'Create your captain account, then finish KYC to go '
                      'online.',
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
                      label: 'Mobile number',
                      hint: '98450 12345',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.phone_outlined,
                      validator: (v) {
                        final digits =
                            (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 10) return 'Enter a 10-digit number';
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
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Create a password';
                        if (v.length < 6) return 'Use at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: ZSpacing.xl),
                    ZButton(
                      label: 'Create partner account',
                      loading: auth.busy,
                      onPressed: auth.busy ? null : _submit,
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    Text(
                      'By continuing you agree to the Zuum Partner Terms and '
                      'confirm you hold a valid driving licence.',
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
                            'Already a partner?',
                            style: ZTypography.body
                                .copyWith(color: ZColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Sign in'),
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
