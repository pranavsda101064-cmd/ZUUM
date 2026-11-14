import 'package:flutter/material.dart';

import 'z_badge.dart';

/// Booking/trip status → label + tone. The app maps domain status → tone.
class ZStatusBadge extends StatelessWidget {
  const ZStatusBadge({super.key, required this.label, this.tone = ZBadgeTone.neutral});

  final String label;
  final ZBadgeTone tone;

  /// Convenience mapping used by the customer app for `BookingStatus`.
  static ZStatusBadge forStatus(String apiStatus, {required String label}) {
    final tone = switch (apiStatus) {
      'CREATED' || 'PRICED' => ZBadgeTone.neutral,
      'SEARCHING' => ZBadgeTone.highlight,
      'ASSIGNED' || 'DRIVER_ARRIVING' || 'IN_PROGRESS' => ZBadgeTone.primary,
      'COMPLETED' => ZBadgeTone.success,
      'CANCELLED' || 'FAILED' => ZBadgeTone.error,
      _ => ZBadgeTone.neutral,
    };
    return ZStatusBadge(label: label, tone: tone);
  }

  @override
  Widget build(BuildContext context) => ZBadge(label: label, tone: tone);
}
