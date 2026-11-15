import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'partner_theme.dart';
import 'router.dart';

class PartnerApp extends ConsumerWidget {
  const PartnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(partnerRouterProvider);
    return MaterialApp.router(
      title: 'Zuum Partner',
      debugShowCheckedModeBanner: false,
      theme: PartnerTheme.light(),
      routerConfig: router,
    );
  }
}
