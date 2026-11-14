import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

/// Bottom-nav shell for the four customer tabs (state preserved per branch).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: ZBottomNav(
        selectedIndex: shell.currentIndex,
        onSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        items: const [
          ZBottomNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          ZBottomNavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Activity',
          ),
          ZBottomNavItem(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
          ),
          ZBottomNavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
