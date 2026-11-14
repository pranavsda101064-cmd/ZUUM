import 'package:flutter/material.dart';

import '../tokens/colors.dart';

class ZDivider extends StatelessWidget {
  const ZDivider({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(color: ZColors.divider, indent: indent, endIndent: endIndent);
  }
}
