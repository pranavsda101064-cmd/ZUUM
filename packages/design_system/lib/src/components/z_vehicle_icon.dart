import 'package:flutter/material.dart';

import 'z_illustration.dart';

/// Canonical vehicle artwork used wherever a service category is shown.
class ZVehicleIcon extends StatelessWidget {
  const ZVehicleIcon({
    super.key,
    required this.categoryCode,
    this.width = 48,
    this.height = 32,
    this.semanticLabel,
  });

  final String categoryCode;
  final double width;
  final double height;
  final String? semanticLabel;

  static const _assets = <String, String>{
    'bike': 'veh_bike',
    'auto': 'veh_auto',
    'hatchback': 'veh_hatchback',
    'mini': 'veh_hatchback',
    'sedan': 'veh_sedan',
    'premium': 'veh_sedan',
    'suv': 'veh_suv',
    'goods_2w': 'veh_2w_goods',
    'goods_3w': 'veh_3w_goods',
    'ace': 'veh_ace',
    'pickup': 'veh_pickup',
    'van': 'veh_ace',
    'tempo': 'veh_tempo',
  };

  static const _aliases = <String, String>{
    'tata ace': 'ace',
    '3w cargo': 'goods_3w',
    '2w parcel': 'goods_2w',
    'mini': 'hatchback',
    'premium': 'sedan',
  };

  static String assetFor(String categoryCode) {
    final key = categoryCode.toLowerCase().trim();
    final code = _aliases[key] ?? key;
    return _assets[code] ?? 'veh_sedan';
  }

  @override
  Widget build(BuildContext context) {
    return ZIllustration(
      assetFor(categoryCode),
      width: width,
      height: height,
      semanticLabel: semanticLabel,
    );
  }
}
