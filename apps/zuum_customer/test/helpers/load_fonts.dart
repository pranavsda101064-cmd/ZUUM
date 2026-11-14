import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Zuum's bundled fonts in widget tests.
///
/// Without this, flutter_test renders everything in the Ahem test font
/// (every glyph is a square), which makes text ~2x too wide and triggers
/// false layout overflows.
Future<void> loadZuumFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final path in assets) {
      try {
        final data = await rootBundle.load(path);
        loader.addFont(Future.value(data));
      } catch (_) {
        // Missing font shouldn't fail the suite — Ahem fallback still runs.
      }
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  await load('NotoSansKannada', [
    'assets/fonts/NotoSansKannada-Regular.ttf',
    'assets/fonts/NotoSansKannada-SemiBold.ttf',
  ]);
}
