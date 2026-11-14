import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

/// Bottom-nav shell for the partner app: Home (online/offers), Earnings,
/// Vehicles & fleet, Account. State preserved per branch.
class PartnerShell extends StatelessWidget {
  const PartnerShell({super.key, required this.shell});

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
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Earnings',
          ),
          ZBottomNavItem(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping_rounded,
            label: 'Vehicles',
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
