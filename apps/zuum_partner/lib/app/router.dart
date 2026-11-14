import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_tab.dart';
import '../features/onboarding/kyc_pending_screen.dart';
import '../features/onboarding/kyc_wizard.dart';
import '../features/shell/partner_shell.dart';
import '../features/splash/partner_splash.dart';
import '../features/trip/trip_screen.dart';
import '../shared/placeholder_page.dart';
import 'auth_controller.dart';

/// Partner navigation with auth + KYC gates:
/// unknown → splash · unauthenticated → login · authenticated:
///   draft/rejected KYC → wizard · submitted → pending · approved → shell.
final partnerRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(partnerAuthProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  const authRoutes = {'/auth/login', '/auth/register'};

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(partnerAuthProvider);
      final loc = state.matchedLocation;

      switch (auth.status) {
        case PartnerAuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case PartnerAuthStatus.unauthenticated:
          // Splash is only the holding screen while the session is resolving
          // (status unknown). Once resolved, auth screens are the destination.
          if (authRoutes.contains(loc)) return null;
          return '/auth/login';
        case PartnerAuthStatus.authenticated:
          if (auth.isApproved) {
            final gated = loc == '/splash' ||
                loc == '/onboarding' ||
                loc == '/onboarding/pending' ||
                authRoutes.contains(loc);
            return gated ? '/home' : null;
          }
          if (auth.kycStatus == KycStatus.submitted) {
            return loc == '/onboarding/pending' ? null : '/onboarding/pending';
          }
          return loc == '/onboarding' ? null : '/onboarding';
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const PartnerSplash()),
      GoRoute(
        path: '/auth/login',
        builder: (_, _) => const PartnerLoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const PartnerRegisterScreen(),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const KycWizard()),
      GoRoute(
        path: '/onboarding/pending',
        builder: (_, _) => const KycPendingScreen(),
      ),
      GoRoute(path: '/trip', builder: (_, _) => const TripScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => PartnerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const HomeTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/earnings',
              builder: (_, _) => const PlaceholderPage(
                title: 'Earnings',
                subtitle:
                    'Daily / weekly / monthly earnings, commission split and '
                    'payouts land in Batch 7.',
                illustration: 'empty_tumbler',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/vehicles',
              builder: (_, _) => const PlaceholderPage(
                title: 'Vehicles & fleet',
                subtitle:
                    'Vehicle management, document expiry and the fleet console '
                    'land in Batch 7.',
                illustration: 'veh_ace',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/account',
              builder: (_, _) => const PlaceholderPage(
                title: 'Partner account',
                subtitle:
                    'Profile, KYC status, ratings and settings land in Batch 8.',
                illustration: 'empty_generic',
              ),
            ),
          ]),
        ],
      ),
    ],
  );
});
