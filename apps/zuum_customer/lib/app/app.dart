import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_design_system/design_system.dart';

import 'router.dart';

class ZuumApp extends ConsumerWidget {
  const ZuumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Zuum',
      debugShowCheckedModeBanner: false,
      theme: ZuumTheme.light(),
      routerConfig: router,
    );
  }
}
