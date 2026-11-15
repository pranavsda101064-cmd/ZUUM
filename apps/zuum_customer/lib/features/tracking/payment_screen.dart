import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';
import '../wallet/wallet_providers.dart';

/// Trip completed — Gemini spec §2h: hero fare card with odometer total and
/// Kannada gratitude, captain tip card ("Most tipped" marigold tag),
/// payment radio tiles (wallet balance badge), sticky pay CTA.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentMethod _method = PaymentMethod.cash;
  int _tipPaise = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final booking = ref.read(activeBookingProvider);
    if (booking != null) _method = booking.paymentMethod;
  }

  Future<void> _pay(Booking booking) async {
    setState(() => _busy = true);
    try {
      if (_method == PaymentMethod.upi || _method == PaymentMethod.card) {
        // Simulated gateway checkout (Razorpay drops in behind PaymentGateway).
        final gatewayResult = await ref.read(paymentGatewayProvider).payTrip(
              bookingId: booking.id,
              amountPaise: booking.quotedFarePaise + _tipPaise,
              method: _method,
            );
        if (!gatewayResult.success) {
          throw ApiException(
            message: gatewayResult.failureReason ?? 'Payment failed',
            statusCode: 400,
            code: 'payment_failed',
          );
        }
      }
      final paid = await ref.read(apiContractProvider).payBooking(
            bookingId: booking.id,
            method: _method,
            tipPaise: _tipPaise,
          );
      // Reflect the settled payment on the active booking (receipt, etc).
      ref.read(activeBookingProvider.notifier).set(paid);
      ref.invalidate(bookingsProvider);
      ref.invalidate(walletProvider);
      if (!mounted) return;
      context.pushReplacement('/booking/rating');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed. Try again.')),
      );
    }
  }

  Future<void> _customTip() async {
    final controller = TextEditingController();
    await ZSheet.show<void>(
      context: context,
      title: 'Custom tip',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZTextField(
            controller: controller,
            label: 'Amount (₹)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: ZSpacing.xl),
          ZButton(
            label: 'Add tip',
            onPressed: () {
              final rupees = int.tryParse(controller.text.trim()) ?? 0;
              if (rupees > 0) {
                setState(() => _tipPaise = rupees * 100);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(activeBookingProvider);
    final wallet = ref.watch(walletProvider);

    if (booking == null) {
      return Scaffold(
        backgroundColor: ZColors.background,
        appBar: const ZAppBar(title: 'Payment'),
        body: ZEmptyState(
          title: 'Nothing to pay',
          subtitle: 'Your completed trips will appear here.',
          actionLabel: 'Back to home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    final total = booking.quotedFarePaise + _tipPaise;
    final captainName =
        booking.driver?.name.split(' ').first ?? 'your captain';

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: booking.isGoods ? 'Delivery payment' : 'Trip complete',
        showBack: false,
        actions: [
          TextButton(
            onPressed: () => context.go('/support'),
            child: const Text('Help'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          // Hero fare card.
          ZCard(
            padding: const EdgeInsets.all(ZSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ZColors.successTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: ZColors.success),
                      const SizedBox(width: 4),
                      Text(
                        booking.isGoods
                            ? 'Delivered to ${booking.receiverName ?? 'receiver'}'
                            : 'Arrived at ${booking.dropAddress}',
                        style: ZTypography.overline.copyWith(
                          color: ZColors.success,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZSpacing.md),
                ZOdometerText(
                  ZFormat.inr(total),
                  style: ZTypography.display.copyWith(
                    fontSize: 32,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: ZSpacing.xs),
                Text(
                  'ನಮ್ಮ ಜೊತೆ ಪ್ರಯಾಣಿಸಿದ್ದಕ್ಕೆ ಧನ್ಯವಾದಗಳು',
                  style: ZTypography.kannada(
                    fontSize: 13,
                    color: ZColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),

          // Captain tip card.
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ZAvatar(
                      initials: booking.driver?.name.isNotEmpty == true
                          ? booking.driver!.name.substring(0, 1)
                          : 'D',
                      size: 36,
                    ),
                    const SizedBox(width: ZSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a tip for $captainName',
                            style: ZTypography.bodyStrong,
                          ),
                          Text(
                            '100% goes directly to your captain',
                            style: ZTypography.caption.copyWith(
                              color: ZColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpacing.lg),
                Row(
                  children: [
                    for (final tip in const [1000, 2000, 5000]) ...[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: ZSpacing.sm),
                          child: _TipChip(
                            label: ZFormat.inr(tip),
                            selected: _tipPaise == tip,
                            mostTipped: tip == 2000,
                            onTap: () => setState(() => _tipPaise = tip),
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: _TipChip(
                        label: 'Custom',
                        selected: _tipPaise > 0 &&
                            _tipPaise != 1000 &&
                            _tipPaise != 2000 &&
                            _tipPaise != 5000,
                        onTap: _customTip,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),

          // Payment method radio tiles.
          ZCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZSpacing.lg,
                    ZSpacing.lg,
                    ZSpacing.lg,
                    ZSpacing.xs,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('PAYMENT METHOD', style: ZTypography.overline),
                  ),
                ),
                _MethodTile(
                  title: 'Zuum Wallet',
                  trailing: wallet.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (w) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ZColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        ZFormat.inr(w.balancePaise),
                        style: ZTypography.overline.copyWith(
                          color: ZColors.primary,
                          letterSpacing: 0.2,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  selected: _method == PaymentMethod.wallet,
                  enabled: (wallet.value?.balancePaise ?? 0) >= total,
                  onTap: () => setState(() => _method = PaymentMethod.wallet),
                ),
                const Divider(height: 1, indent: 56),
                _MethodTile(
                  title: 'UPI (Google Pay / PhonePe)',
                  selected: _method == PaymentMethod.upi,
                  onTap: () => setState(() => _method = PaymentMethod.upi),
                ),
                const Divider(height: 1, indent: 56),
                _MethodTile(
                  title: 'Cash / Pay captain QR',
                  selected: _method == PaymentMethod.cash,
                  onTap: () => setState(() => _method = PaymentMethod.cash),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          const ZBadge(
            label: 'Payments run on a mock gateway until Razorpay keys land',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            ZSpacing.lg,
            ZSpacing.md,
            ZSpacing.lg,
            ZSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: ZColors.surface,
            border: Border(top: BorderSide(color: ZColors.divider)),
          ),
          child: ZButton(
            label: switch (_method) {
              PaymentMethod.cash => 'Confirm cash payment · ${ZFormat.inr(total)}',
              PaymentMethod.upi => 'Pay ${ZFormat.inr(total)} via UPI',
              PaymentMethod.wallet => 'Pay ${ZFormat.inr(total)} from wallet',
              PaymentMethod.card => 'Pay ${ZFormat.inr(total)}',
            },
            loading: _busy,
            onPressed: _busy ? null : () => _pay(booking),
          ),
        ),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.mostTipped = false,
  });

  final String label;
  final bool selected;
  final bool mostTipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (mostTipped)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ZColors.success,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Most tipped',
              style: ZTypography.overline.copyWith(
                color: ZColors.dark,
                fontSize: 9,
                letterSpacing: 0.2,
              ),
            ),
          ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? ZColors.accent : ZColors.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? ZColors.primary : ZColors.divider,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: ZTypography.bodyStrong.copyWith(
                color: selected ? ZColors.primary : ZColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpacing.lg,
            vertical: ZSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ZTypography.body.copyWith(
                    color: enabled ? ZColors.textPrimary : ZColors.textTertiary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: ZSpacing.sm),
                trailing!,
              ],
              const SizedBox(width: ZSpacing.sm),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? ZColors.primary : ZColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
