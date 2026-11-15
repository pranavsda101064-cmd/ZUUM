import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

import 'admin_auth.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await AdminScope.of(context).login(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AdminScope.of(context);
    return Scaffold(
      backgroundColor: ZColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final form = _formPanel(auth);
          if (!wide) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _brandHeader(compact: true),
                  Padding(
                    padding: const EdgeInsets.all(ZSpacing.xxl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: form,
                    ),
                  ),
                ],
              ),
            );
          }
          return Row(
            children: [
              Expanded(flex: 11, child: _brandHeader()),
              Expanded(
                flex: 9,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: form,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _brandHeader({bool compact = false}) {
    return Container(
      width: double.infinity,
      height: compact ? 260 : null,
      color: ZColors.dark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ZPhoto('blr_skyline_night'),
          const ZScrim(opacity: 0.86),
          Padding(
            padding: EdgeInsets.all(compact ? ZSpacing.xxl : 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ZBrandMark(onDark: true, scale: 0.9),
                if (!compact) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'One city.\nOne command center.',
                        style: ZTypography.display.copyWith(
                          color: ZColors.onDark,
                          fontSize: 42,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: ZSpacing.lg),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Text(
                          'Live demand, dispatch, KYC, payouts and support — '
                          'operated from a single Bengaluru desk.',
                          style: ZTypography.body.copyWith(
                            color: ZColors.onDarkSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: ZSpacing.xxl),
                      const Wrap(
                        spacing: ZSpacing.lg,
                        runSpacing: ZSpacing.sm,
                        children: [
                          _Signal(label: 'DISPATCH', icon: Icons.radar_rounded),
                          _Signal(label: 'DRIVERS', icon: Icons.groups_2_outlined),
                          _Signal(
                            label: 'MONEY',
                            icon: Icons.account_balance_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'ZUUM OPS · BENGALURU',
                    style: ZTypography.overline.copyWith(
                      color: ZColors.onDarkSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formPanel(AdminAuth auth) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ZBrandMark(),
          const SizedBox(height: ZSpacing.xxl),
          Text('Ops sign in', style: ZTypography.display.copyWith(fontSize: 30)),
          const SizedBox(height: ZSpacing.xs),
          Text(
            'Staff access only. Use your Zuum operations account.',
            style: ZTypography.body.copyWith(color: ZColors.textSecondary),
          ),
          const SizedBox(height: ZSpacing.xxl),
          if (auth.error != null) ...[
            Container(
              padding: const EdgeInsets.all(ZSpacing.md),
              decoration: BoxDecoration(
                color: ZColors.errorTint,
                borderRadius: BorderRadius.circular(ZRadii.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 18, color: ZColors.error),
                  const SizedBox(width: ZSpacing.sm),
                  Expanded(
                    child: Text(
                      auth.error!,
                      style: ZTypography.caption.copyWith(color: ZColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpacing.lg),
          ],
          ZTextField(
            controller: _email,
            label: 'Work email',
            hint: 'you@zuum.in',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.alternate_email_rounded,
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Enter your work email';
              if (!email.contains('@')) return 'Enter a valid email';
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
            validator: (value) => (value == null || value.isEmpty)
                ? 'Enter your password'
                : null,
          ),
          const SizedBox(height: ZSpacing.xxl),
          ZButton(
            label: 'Enter command center',
            icon: Icons.arrow_forward_rounded,
            loading: auth.busy,
            onPressed: auth.busy ? null : _submit,
          ),
          const SizedBox(height: ZSpacing.lg),
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 14, color: ZColors.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Actions are audited. Sessions are device-scoped.',
                  style: ZTypography.caption.copyWith(
                    color: ZColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ZColors.onDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZColors.darkOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ZColors.onDarkSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: ZTypography.overline.copyWith(
              color: ZColors.onDarkSecondary,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
