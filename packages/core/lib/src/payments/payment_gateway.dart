import 'dart:async';

import '../models/models.dart';

class PaymentResult {
  const PaymentResult.success({this.transactionId})
      : success = true,
        failureReason = null;

  const PaymentResult.failure(this.failureReason)
      : success = false,
        transactionId = null;

  final bool success;
  final String? transactionId;
  final String? failureReason;
}

/// Payment gateway seam. [MockPaymentGateway] is DEV-ONLY; the Razorpay
/// implementation drops in behind this interface when keys are provided.
abstract interface class PaymentGateway {
  /// Charge a trip (UPI / wallet / card). Cash is settled with the driver.
  Future<PaymentResult> payTrip({
    required String bookingId,
    required int amountPaise,
    required PaymentMethod method,
  });

  /// Top up the Zuum wallet.
  Future<PaymentResult> topUp({
    required int amountPaise,
    required PaymentMethod method,
  });
}

/// ============================================================
/// DEV-ONLY MOCK PAYMENT GATEWAY — `ENV=mock` only.
/// Simulates gateway latency and outcomes. No real money moves.
/// ============================================================
class MockPaymentGateway implements PaymentGateway {
  MockPaymentGateway({this.latency = const Duration(milliseconds: 1200)});

  final Duration latency;

  var _seq = 0;

  Future<void> _wait() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  @override
  Future<PaymentResult> payTrip({
    required String bookingId,
    required int amountPaise,
    required PaymentMethod method,
  }) async {
    await _wait();
    if (method == PaymentMethod.cash) {
      return PaymentResult.success(transactionId: 'cash-$bookingId');
    }
    if (amountPaise <= 0) {
      return const PaymentResult.failure('Invalid amount');
    }
    // Simulated gateway approval — dev-only.
    return PaymentResult.success(
      transactionId: 'mock-pay-${++_seq}-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<PaymentResult> topUp({
    required int amountPaise,
    required PaymentMethod method,
  }) async {
    await _wait();
    if (amountPaise < 1000) {
      // Minimum ₹10 top-up.
      return const PaymentResult.failure('Minimum top-up is ₹10');
    }
    return PaymentResult.success(
      transactionId: 'mock-topup-${++_seq}',
    );
  }
}
