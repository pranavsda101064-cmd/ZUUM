import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

class EarningsRangeController extends Notifier<EarningsRange> {
  @override
  EarningsRange build() => EarningsRange.today;

  void select(EarningsRange range) => state = range;
}

final earningsRangeProvider =
    NotifierProvider<EarningsRangeController, EarningsRange>(
  EarningsRangeController.new,
);

final earningsSummaryProvider = FutureProvider<EarningsSummary>((ref) {
  final range = ref.watch(earningsRangeProvider);
  return ref.watch(partnerApiProvider).earnings(range);
});

final earningTripsProvider = FutureProvider<Paged<EarningEntry>>(
  (ref) => ref.watch(partnerApiProvider).earningTrips(),
);

final payoutsProvider = FutureProvider<Paged<Payout>>(
  (ref) => ref.watch(partnerApiProvider).payouts(),
);

/// Start of the selected window, used to filter the ledger client-side
/// (the mock returns the full list; the real API will filter server-side).
DateTime rangeStart(EarningsRange range) {
  final now = DateTime.now();
  return switch (range) {
    EarningsRange.today => DateTime(now.year, now.month, now.day),
    EarningsRange.week => now.subtract(const Duration(days: 7)),
    EarningsRange.month => now.subtract(const Duration(days: 30)),
  };
}
