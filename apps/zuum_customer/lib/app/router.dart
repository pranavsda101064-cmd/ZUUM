import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/booking/category_fare_screen.dart';
import '../features/booking/goods_details_screen.dart';
import '../features/booking/location_search_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/offers/offers_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/safety/safety_screen.dart';
import '../features/settings/gst_trusted_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/account_tab.dart';
import '../features/shell/activity_tab.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/home_tab.dart';
import '../features/shell/wallet_tab.dart';
import '../features/splash/splash_screen.dart';
import '../features/support/support_screen.dart';
import '../features/tracking/payment_screen.dart';
import '../features/tracking/pod_screen.dart';
import '../features/tracking/rating_screen.dart';
import '../features/tracking/receipt_screen.dart';
import '../features/tracking/tracking_screen.dart';
import 'auth_controller.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  const authRoutes = ['/auth/login', '/auth/register', '/auth/forgot'];

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      switch (auth.status) {
        case AuthStatus.unknown:
          // Splash is the decision point — everything funnels through it.
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.unauthenticated:
          if (loc == '/splash' || loc == '/onboarding' || authRoutes.contains(loc)) {
            return null;
          }
          return '/auth/login';
        case AuthStatus.authenticated:
          if (loc == '/splash' || loc == '/onboarding' || authRoutes.contains(loc)) {
            return '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/auth/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/auth/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/search', builder: (_, _) => const LocationSearchScreen()),
      GoRoute(path: '/booking/goods', builder: (_, _) => const GoodsDetailsScreen()),
      GoRoute(
        path: '/booking/options',
        builder: (_, _) => const CategoryFareScreen(),
      ),
      GoRoute(
        path: '/booking/tracking',
        builder: (_, _) => const TrackingScreen(),
      ),
      GoRoute(
        path: '/booking/pod',
        builder: (_, _) => const PodScreen(),
      ),
      GoRoute(
        path: '/booking/payment',
        builder: (_, _) => const PaymentScreen(),
      ),
      GoRoute(
        path: '/booking/rating',
        builder: (_, _) => const RatingScreen(),
      ),
      GoRoute(
        path: '/booking/receipt',
        builder: (_, _) => const ReceiptScreen(),
      ),
      GoRoute(path: '/offers', builder: (_, _) => const OffersScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/support', builder: (_, _) => const SupportScreen()),
      GoRoute(path: '/safety', builder: (_, _) => const SafetyScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/profile',
        builder: (_, _) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings/addresses',
        builder: (_, _) => const SavedAddressesScreen(),
      ),
      GoRoute(
        path: '/settings/payments',
        builder: (_, _) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: '/settings/gst',
        builder: (_, _) => const GstDetailsScreen(),
      ),
      GoRoute(
        path: '/settings/trusted',
        builder: (_, _) => const TrustedContactsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeTab()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/activity', builder: (_, _) => const ActivityTab()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/wallet', builder: (_, _) => const WalletTab()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, _) => const AccountTab()),
          ]),
        ],
      ),
    ],
  );
});
