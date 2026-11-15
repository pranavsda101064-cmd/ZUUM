import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_core/core.dart';

void main() {
  test('partner profile accepts DRF decimal strings', () {
    final profile = PartnerProfile.fromJson({
      'id': 'partner-1',
      'kyc_status': 'approved',
      'approval_status': 'active',
      'rating_avg': '4.80',
      'rating_count': 126,
      'acceptance_rate': '92.5',
      'document_count': 3,
      'required_document_count': 3,
    });

    expect(profile.ratingAvg, 4.8);
    expect(profile.acceptanceRate, 92.5);
    expect(profile.ratingCount, 126);
  });

  test('earnings accepts decimal rate strings', () {
    final summary = EarningsSummary.fromJson({
      'gross_paise': 25000,
      'commission_paise': 5000,
      'net_paise': 20000,
      'trips': 4,
      'online_minutes': 120,
      'acceptance_rate': '88.0',
      'cancellation_rate': '0.0',
    });

    expect(summary.acceptanceRate, 88);
    expect(summary.cancellationRate, 0);
  });
}
