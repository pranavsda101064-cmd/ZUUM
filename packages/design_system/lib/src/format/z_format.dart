/// Formatting helpers — INR currency, distance, duration.
abstract final class ZFormat {
  /// `23400` paise → `₹234` / `₹234.50` (Indian grouping: 1,23,456).
  static String inr(int paise, {bool compact = false}) {
    final negative = paise < 0;
    final abs = paise.abs();
    final rupees = abs ~/ 100;
    final cents = abs % 100;
    if (compact && rupees >= 100000) {
      // ₹1.2L / ₹1.2Cr for tight spaces (earnings, summaries).
      if (rupees >= 10000000) {
        return '${negative ? '-' : ''}₹${_trim(rupees / 10000000)}Cr';
      }
      return '${negative ? '-' : ''}₹${_trim(rupees / 100000)}L';
    }
    final s = _indianGrouped(rupees);
    final body = cents > 0 ? '$s.${cents.toString().padLeft(2, '0')}' : s;
    return '${negative ? '-' : ''}₹$body';
  }

  static String _indianGrouped(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var head = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    parts.insert(0, head);
    return '${parts.join(',')},$last3';
  }

  static String _trim(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  /// `1850` metres → `1.9 km` / `450` metres → `450 m`.
  static String distance(int meters) {
    if (meters < 1000) return '$meters m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  /// `240` seconds → `4 min` / `4500` seconds → `1 hr 15 min`.
  static String duration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  /// Plate formatting is server-truth; this only normalizes spacing.
  static String plate(String raw) => raw.trim().toUpperCase();

  /// `12 Nov 2026` — date-only (document expiry, invoices).
  static String shortDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `12 Nov, 10:00 AM` (this year) — for scheduled trips and history rows.
  static String shortDateTime(DateTime dt) {
    final h12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$h12:${dt.minute.toString().padLeft(2, '0')} $suffix';
    return '${dt.day} ${_months[dt.month - 1]}, $time';
  }

  /// `Mon 12 Nov · 10:00 AM` — day-precise variant.
  static String dayDateTime(DateTime dt) {
    final base = shortDateTime(dt);
    final comma = base.indexOf(',');
    return '${_days[dt.weekday - 1]} ${base.substring(0, comma)} ·'
        '${base.substring(comma + 1)}';
  }
}
