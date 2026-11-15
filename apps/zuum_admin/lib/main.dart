import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

import 'admin_auth.dart';
import 'admin_theme.dart';
import 'dashboard_shell.dart';
import 'login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminRoot());
}

class AdminRoot extends StatefulWidget {
  const AdminRoot({super.key});

  @override
  State<AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<AdminRoot> {
  late final AdminAuth _auth;

  @override
  void initState() {
    super.initState();
    _auth = AdminAuth()..restore();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      auth: _auth,
      child: AnimatedBuilder(
        animation: _auth,
        builder: (context, _) {
          return MaterialApp(
            title: 'Zuum Ops',
            debugShowCheckedModeBanner: false,
            theme: adminTheme(),
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            home: switch (_auth.status) {
              AdminAuthStatus.booting => const _AdminBoot(),
              AdminAuthStatus.signedOut => const AdminLoginScreen(),
              AdminAuthStatus.signedIn => DashboardShell(auth: _auth),
            },
          );
        },
      ),
    );
  }
}

class _AdminBoot extends StatelessWidget {
  const _AdminBoot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.dark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZBrandMark(onDark: true, scale: 1.1),
            const SizedBox(height: 24),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: ZColors.darkRaised,
                valueColor: AlwaysStoppedAnimation(
                  ZColors.onDark.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Opening the command center…',
              style: ZTypography.caption.copyWith(
                color: ZColors.onDarkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
