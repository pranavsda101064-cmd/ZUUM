import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line-art illustrations shipped with the design-system package.
/// Loads `packages/zuum_design_system/assets/illustrations/{name}.svg` so any
/// app can use them without re-declaring assets.
class ZIllustration extends StatelessWidget {
  const ZIllustration(
    this.name, {
    super.key,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String name;
  final double? height;
  final double? width;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/illustrations/$name.svg',
      package: 'zuum_design_system',
      height: height,
      width: width,
      fit: fit,
      semanticsLabel: semanticLabel,
    );
  }
}
