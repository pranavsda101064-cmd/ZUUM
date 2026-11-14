import 'package:flutter/material.dart';

/// Themed boolean toggle (wraps Switch with Zuum track colors — see theme).
class ZToggle extends StatelessWidget {
  const ZToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final toggle = Switch(value: value, onChanged: onChanged);
    if (label == null) return toggle;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label!), toggle],
    );
  }
}
