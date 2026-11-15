import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Boarding PIN pill — Highlight fill with Dark ink (10.4:1 contrast),
/// mimicking the black-and-yellow auto fare metre. Lives on dark headers.
class ZPinPill extends StatelessWidget {
  const ZPinPill({super.key, required this.pin, this.label = 'PIN'});

  final String pin;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ZColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$label $pin',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ZColors.dark,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 1.0,
            height: 1,
          ),
        ),
      ),
    );
  }
}
