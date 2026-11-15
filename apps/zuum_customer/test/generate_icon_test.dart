import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_design_system/design_system.dart';

import 'helpers/load_fonts.dart';

/// One-off generator: renders the Zuum launcher icon (1024×1024 PNG) from
/// the brand mark. Run: flutter test test/generate_icon_test.dart
void main() {
  setUpAll(loadZuumFonts);

  test('generate zuum launcher icon png', () async {
    const size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Full-bleed dark background (adaptive icon base).
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = ZColors.dark,
    );

    // Rounded inner tile for depth.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(64, 64, size - 128, size - 128),
        const Radius.circular(200),
      ),
      Paint()..color = const Color(0xFF0B1E20),
    );

    // The Z — Inter Bold in the accent tone.
    final zText = TextPainter(
      text: TextSpan(
        text: 'Z',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 560,
          fontWeight: FontWeight.w700,
          color: ZColors.accent,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zText.paint(
      canvas,
      Offset((size - zText.width) / 2, (size - zText.height) / 2 - 30),
    );

    // The motion spark — marigold dot with a dark ring.
    canvas.drawCircle(const Offset(700, 760), 70, Paint()..color = ZColors.primary);
    canvas.drawCircle(
      const Offset(700, 760),
      84,
      Paint()
        ..color = ZColors.dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(1024, 1024);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);

    final file = File('assets/icon/zuum_icon.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(10000));
  });
}
