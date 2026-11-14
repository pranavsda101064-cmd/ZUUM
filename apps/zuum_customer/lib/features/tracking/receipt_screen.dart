import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';
import 'receipt_pdf.dart';
import 'trip_controller.dart';

/// Trip receipt — Gemini spec §2j: perforated ticket card, invoice header,
/// paid banner, static mini-map, itemised ledger with GST note, share footer.
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _pdfBusy = false;
  bool _pdfDone = false;

  Future<void> _downloadPdf(Booking booking, int finalFare, int gst, int tip) async {
    setState(() => _pdfBusy = true);
    try {
        final bytes = ReceiptPdf.build(
          title: 'ZUUM Tax Invoice & Receipt',
          lines: [
            'Invoice #BLR-${booking.id.substring(0, 4).toUpperCase()}',
            ZFormat.dayDateTime(booking.createdAt.toLocal()),
            '',
            booking.serviceCategoryName,
            booking.pickupAddress,
            '-> ${booking.dropAddress}',
            '',
            'Trip fare: ${ZFormat.inr(finalFare - gst - tip)}',
            'Platform & GST (5%): ${ZFormat.inr(gst)}',
            if (tip > 0) 'Captain tip: ${ZFormat.inr(tip)}',
            'Grand total: ${ZFormat.inr(finalFare)}',
            'Payment: ${booking.paymentState == PaymentState.paid ? 'PAID' : 'DUE'}',
            '',
            'Captain: ${booking.driver?.name ?? '-'}'
            '${booking.vehicle != null ? ' · ${booking.vehicle!.registrationNumber}' : ''}',
            'Thank you for travelling with Zuum.',
          ],
        );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: 'zuum-receipt-${booking.id}.pdf',
              mimeType: 'application/pdf',
            ),
          ],
          text: 'Zuum receipt ${booking.id}',
        ),
      );
      if (mounted) {
        setState(() {
          _pdfBusy = false;
          _pdfDone = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt PDF ready to save/share')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pdfBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate PDF. Share as text instead.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(activeBookingProvider);
    final podProof = ref.watch(podProofProvider);

    if (booking == null) {
      return Scaffold(
        backgroundColor: ZColors.background,
        appBar: const ZAppBar(title: 'Receipt'),
        body: ZEmptyState(
          title: 'No receipt',
          subtitle: 'Completed trip receipts appear in Activity.',
          actionLabel: 'Back to home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    final finalFare = booking.finalFarePaise ?? booking.quotedFarePaise;
    final tip = finalFare - booking.quotedFarePaise;
    // Inclusive GST split (5%) — display component of the fare.
    final gst = (finalFare * 5) ~/ 105;
    final fareExGst = finalFare - gst;

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: 'Tax invoice & receipt',
        showBack: false,
        actions: [
          ZIconButton(
            icon: Icons.close_rounded,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          ZTicketCard(
            top: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'ZUUM',
                      style: ZTypography.titleMd.copyWith(
                        color: ZColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Invoice #BLR-${booking.id.substring(0, 4).toUpperCase()}',
                          style: ZTypography.overline.copyWith(
                            color: ZColors.textTertiary,
                            letterSpacing: 0.2,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        Text(
                          ZFormat.dayDateTime(booking.createdAt.toLocal()),
                          style: ZTypography.caption.copyWith(
                            color: ZColors.textSecondary,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: ZSpacing.lg),
                // Paid banner.
                Container(
                  padding: const EdgeInsets.all(ZSpacing.md),
                  decoration: BoxDecoration(
                    color: ZColors.background,
                    borderRadius: BorderRadius.circular(ZRadii.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total paid',
                                  style: ZTypography.bodyStrong,
                                ),
                                const SizedBox(width: ZSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: booking.paymentState ==
                                            PaymentState.paid
                                        ? ZColors.successTint
                                        : ZColors.highlightTint,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    booking.paymentState == PaymentState.paid
                                        ? 'PAID'
                                        : 'DUE',
                                    style: ZTypography.overline.copyWith(
                                      color: booking.paymentState ==
                                              PaymentState.paid
                                          ? ZColors.success
                                          : ZColors.dark,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              switch (booking.paymentMethod) {
                                PaymentMethod.cash => 'Cash',
                                PaymentMethod.upi => 'UPI',
                                PaymentMethod.card => 'Card',
                                PaymentMethod.wallet => 'Wallet',
                              },
                              style: ZTypography.caption.copyWith(
                                color: ZColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ZOdometerText(
                        ZFormat.inr(finalFare),
                        style: ZTypography.numericLg,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZSpacing.lg),
                // Static mini-map of the completed route.
                ClipRRect(
                  borderRadius: BorderRadius.circular(ZRadii.md),
                  child: SizedBox(
                    height: 104,
                    child: ZMapView(
                      interactive: false,
                      showAttribution: false,
                      center: ZMapCenter(
                        booking.pickupLat ?? 12.9352,
                        booking.pickupLng ?? 77.6245,
                      ),
                      route: ZMapRoute([
                        ZMapCenter(
                          booking.pickupLat ?? 12.9352,
                          booking.pickupLng ?? 77.6245,
                        ),
                        ZMapCenter(
                          booking.dropLat ?? 12.9719,
                          booking.dropLng ?? 77.6412,
                        ),
                      ]),
                      markers: [
                        ZMapMarker(
                          booking.pickupLat ?? 12.9352,
                          booking.pickupLng ?? 77.6245,
                        ),
                        ZMapMarker(
                          booking.dropLat ?? 12.9719,
                          booking.dropLng ?? 77.6412,
                          color: ZColors.error,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ZSpacing.lg),
                // Timestamps & locations.
                Text(
                  '${ZFormat.dayDateTime(booking.createdAt.toLocal())} · '
                  '${booking.pickupAddress}',
                  style: ZTypography.caption,
                ),
                const SizedBox(height: ZSpacing.sm),
                Text(
                  booking.dropAddress,
                  style: ZTypography.caption,
                ),
                const SizedBox(height: ZSpacing.lg),
                const Divider(height: 1),
                const SizedBox(height: ZSpacing.md),
                // Proof of delivery (goods): signature capture.
                if (booking.isGoods && podProof?.signaturePng != null) ...[
                  Text('RECEIVER SIGNATURE', style: ZTypography.overline),
                  const SizedBox(height: ZSpacing.sm),
                  Container(
                    height: 64,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: ZSpacing.md),
                    decoration: BoxDecoration(
                      color: ZColors.background,
                      borderRadius: BorderRadius.circular(ZRadii.sm),
                      border: Border.all(color: ZColors.divider),
                    ),
                    child: Image.memory(
                      podProof!.signaturePng!,
                      height: 56,
                    ),
                  ),
                  const SizedBox(height: ZSpacing.md),
                ],
                // Itemised ledger.
                _LedgerRow(label: 'Trip fare', amount: fareExGst),
                _LedgerRow(
                  label: 'Platform & GST (5%, included)',
                  amount: gst,
                  muted: true,
                ),
                if (tip > 0)
                  _LedgerRow(label: 'Captain tip (non-taxable)', amount: tip),
                const Divider(height: 1),
                const SizedBox(height: ZSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand total', style: ZTypography.bodyStrong),
                    Text(
                      ZFormat.inr(finalFare),
                      style: ZTypography.numericLg.copyWith(fontSize: 17),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpacing.lg),
                Text(
                  'Captain: ${booking.driver?.name ?? '—'}'
                  '${booking.vehicle != null ? ' · ${booking.vehicle!.registrationNumber}' : ''}',
                  style: ZTypography.overline.copyWith(
                    color: ZColors.textTertiary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: ZSpacing.sm),
                Center(
                  child: Text(
                    'ಧನ್ಯವಾದಗಳು · ಶುಭ ದಿನ',
                    style: ZTypography.kannada(
                      fontSize: 13,
                      color: ZColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            bottom: Row(
              children: [
                Expanded(
                  child: ZButton(
                    label: 'Need help?',
                    variant: ZButtonVariant.secondary,
                    onPressed: () => context.push('/support'),
                  ),
                ),
                const SizedBox(width: ZSpacing.md),
                Expanded(
                  child: ZButton(
                    label: _pdfBusy
                        ? 'Generating PDF...'
                        : _pdfDone
                            ? 'PDF ready ✓'
                            : 'Download PDF',
                    icon: _pdfDone
                        ? Icons.check_rounded
                        : Icons.download_rounded,
                    loading: _pdfBusy,
                    onPressed: () =>
                        _downloadPdf(booking, finalFare, gst, tip),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          Center(
            child: TextButton(
              onPressed: () {
                ref.read(tripControllerProvider.notifier).finish();
                ref.read(activeBookingProvider.notifier).clear();
                ref.read(podProofProvider.notifier).clear();
                ref.invalidate(bookingsProvider);
                context.go('/home');
              },
              child: Text(
                'Done',
                style: ZTypography.bodyStrong
                    .copyWith(color: ZColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.label,
    required this.amount,
    this.muted = false,
  });

  final String label;
  final int amount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: ZTypography.caption.copyWith(
                color: muted ? ZColors.textTertiary : ZColors.textSecondary,
              ),
            ),
          ),
          Text(
            ZFormat.inr(amount),
            style: ZTypography.numeric.copyWith(
              fontSize: 14,
              color: muted ? ZColors.textTertiary : ZColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
