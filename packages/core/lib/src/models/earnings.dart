import 'json_value.dart';

enum EarningsRange { today, week, month }

enum PayoutStatus { pending, processing, paid, failed }

class EarningsSummary {
  const EarningsSummary({
    required this.grossPaise,
    required this.commissionPaise,
    required this.netPaise,
    required this.trips,
    required this.onlineMinutes,
    required this.acceptanceRate,
    required this.cancellationRate,
    this.tipsPaise = 0,
  });

  final int grossPaise;
  final int commissionPaise;
  final int netPaise;
  final int trips;
  final int onlineMinutes;
  final double acceptanceRate;
  final double cancellationRate;
  final int tipsPaise;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        grossPaise: (json['gross_paise'] as num?)?.toInt() ?? 0,
        commissionPaise: (json['commission_paise'] as num?)?.toInt() ?? 0,
        netPaise: (json['net_paise'] as num?)?.toInt() ?? 0,
        trips: (json['trips'] as num?)?.toInt() ?? 0,
        onlineMinutes: (json['online_minutes'] as num?)?.toInt() ?? 0,
        acceptanceRate: jsonDouble(json['acceptance_rate']) ?? 0,
        cancellationRate: jsonDouble(json['cancellation_rate']) ?? 0,
        tipsPaise: (json['tips_paise'] as num?)?.toInt() ?? 0,
      );
}

/// One completed trip in the earnings ledger, with its commission split.
class EarningEntry {
  const EarningEntry({
    required this.bookingId,
    required this.at,
    required this.categoryName,
    required this.isGoods,
    required this.farePaise,
    required this.commissionPaise,
    required this.earningPaise,
    this.paymentMethod = 'cash',
    this.tipPaise = 0,
  });

  final String bookingId;
  final DateTime at;
  final String categoryName;
  final bool isGoods;
  final int farePaise;
  final int commissionPaise;
  final int earningPaise;
  final String paymentMethod;
  final int tipPaise;

  factory EarningEntry.fromJson(Map<String, dynamic> json) => EarningEntry(
        bookingId: json['booking_id'] as String,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        categoryName: json['category_name'] as String? ?? '',
        isGoods: json['is_goods'] as bool? ?? false,
        farePaise: (json['fare_paise'] as num?)?.toInt() ?? 0,
        commissionPaise: (json['commission_paise'] as num?)?.toInt() ?? 0,
        earningPaise: (json['earning_paise'] as num?)?.toInt() ?? 0,
        paymentMethod: json['payment_method'] as String? ?? 'cash',
        tipPaise: (json['tip_paise'] as num?)?.toInt() ?? 0,
      );
}

class Payout {
  const Payout({
    required this.id,
    required this.amountPaise,
    required this.status,
    required this.method,
    this.paidAt,
    this.batchRef,
  });

  final String id;
  final int amountPaise;
  final PayoutStatus status;
  final String method;
  final DateTime? paidAt;
  final String? batchRef;

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
        id: json['id'] as String,
        amountPaise: (json['amount_paise'] as num?)?.toInt() ?? 0,
        status: PayoutStatus.values.asNameMap()[json['status'] as String?] ??
            PayoutStatus.pending,
        method: json['method'] as String? ?? 'bank',
        paidAt: json['paid_at'] == null
            ? null
            : DateTime.tryParse(json['paid_at'] as String),
        batchRef: json['batch_ref'] as String?,
      );
}
