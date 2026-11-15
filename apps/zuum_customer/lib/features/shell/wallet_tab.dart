import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../wallet/wallet_providers.dart';

/// Wallet tab — Gemini spec §2m: dark hero balance card with quick-add
/// chips and preview, linked UPI row, filtered transaction ledger with
/// tinted icon containers, tumbler empty state.
class WalletTab extends ConsumerStatefulWidget {
  const WalletTab({super.key});

  @override
  ConsumerState<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<WalletTab> {
  String _filter = 'All';

  static const _filters = ['All', 'Rides', 'Goods', 'Top-ups'];

  bool _matches(WalletTransaction tx) {
    return switch (_filter) {
      'Rides' =>
        tx.type == WalletTxType.debit && tx.note.toLowerCase().contains('ride'),
      'Goods' =>
        tx.type == WalletTxType.debit &&
            tx.note.toLowerCase().contains('trip'),
      'Top-ups' => tx.type == WalletTxType.topup,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final tx = ref.watch(walletTxProvider);

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Zuum Wallet'),
      body: RefreshIndicator(
        color: ZColors.primary,
        onRefresh: () async {
          ref.invalidate(walletProvider);
          ref.invalidate(walletTxProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(ZSpacing.lg),
          children: [
            // Dark hero balance card.
            wallet.when(
              loading: () => const ZSkeleton(height: 200, radius: ZRadii.lg),
              error: (_, _) => ZErrorState(
                title: 'Could not load wallet',
                message: 'Check your connection and try again.',
                onRetry: () => ref.invalidate(walletProvider),
              ),
              data: (w) => Container(
                padding: const EdgeInsets.all(ZSpacing.xl),
                decoration: BoxDecoration(
                  color: ZColors.dark,
                  borderRadius: BorderRadius.circular(ZRadii.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AVAILABLE BALANCE',
                          style: ZTypography.overline.copyWith(
                            color: ZColors.accent,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: ZColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-pay active',
                          style: ZTypography.overline.copyWith(
                            color: ZColors.onDark,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZSpacing.sm),
                    ZOdometerText(
                      ZFormat.inr(w.balancePaise),
                      style: ZTypography.display.copyWith(
                        fontSize: 32,
                        color: ZColors.onDark,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    Row(
                      children: [
                        for (final preset in const [20000, 50000, 100000])
                          Padding(
                            padding: const EdgeInsets.only(right: ZSpacing.sm),
                            child: _QuickAddChip(
                              label: '+ ${ZFormat.inr(preset)}',
                              onTap: () => _topUp(preset),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: ZSpacing.md),
                    ZButton(
                      label: 'Add money to wallet',
                      size: ZButtonSize.sm,
                      variant: ZButtonVariant.secondary,
                      icon: Icons.add_rounded,
                      onPressed: () => _topUp(20000),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZSpacing.lg),

            // Linked UPI (mock identity — dev data).
            ZCard(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpacing.lg,
                vertical: ZSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined,
                      color: ZColors.primary),
                  const SizedBox(width: ZSpacing.md),
                  Expanded(
                    child: Text('Linked UPI · zuum@okaxis',
                        style: ZTypography.bodyStrong),
                  ),
                  Text(
                    'Manage',
                    style: ZTypography.captionStrong
                        .copyWith(color: ZColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpacing.xl),

            // Filters + ledger.
            Row(
              children: [
                Text('RECENT TRANSACTIONS', style: ZTypography.overline),
                const Spacer(),
                for (final f in _filters) ...[
                  ZChip(
                    label: f,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                  if (f != _filters.last) const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: ZSpacing.sm),
            tx.when(
              loading: () => const ZSkeletonList(itemCount: 3),
              error: (_, _) => const SizedBox.shrink(),
              data: (page) {
                final rows = page.results.where(_matches).toList();
                if (rows.isEmpty) {
                  return const ZEmptyState(
                    illustration: 'empty_tumbler',
                    title: 'No wallet activity yet',
                    subtitle:
                        'Add money once and breeze past change problems at the '
                        'end of every ride.',
                  );
                }
                return Column(
                  children: [
                    for (final t in rows) _TxTile(tx: t),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _topUp(int amountPaise) {
    var amount = amountPaise;
    ZSheet.show<void>(
      context: context,
      title: 'Top up wallet',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add money via UPI. Payments run on a mock gateway until '
              'Razorpay keys land.',
              style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
            ),
            const SizedBox(height: ZSpacing.xl),
            Row(
              children: [
                for (final preset in const [10000, 20000, 50000])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: ZSpacing.sm),
                      child: ZChip(
                        label: ZFormat.inr(preset),
                        selected: amount == preset,
                        onTap: () => setSheetState(() => amount = preset),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZSpacing.lg),
            Text(
              'New balance: ${ZFormat.inr(15000 + amount)}',
              style: ZTypography.numeric.copyWith(color: ZColors.success),
            ),
            const SizedBox(height: ZSpacing.xl),
            ZButton(
              label: 'Top up ${ZFormat.inr(amount)}',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(sheetContext);
                try {
                  final gateway = ref.read(paymentGatewayProvider);
                  final result = await gateway.topUp(
                    amountPaise: amount,
                    method: PaymentMethod.upi,
                  );
                  if (!result.success) {
                    throw ApiException(
                      message: result.failureReason ?? 'Top-up failed',
                      statusCode: 400,
                      code: 'payment_failed',
                    );
                  }
                  await ref.read(apiContractProvider).topUpWallet(
                        amountPaise: amount,
                        method: PaymentMethod.upi,
                      );
                  ref.invalidate(walletProvider);
                  ref.invalidate(walletTxProvider);
                  if (navigator.mounted) navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Wallet topped up ${ZFormat.inr(amount)}'),
                    ),
                  );
                } on ApiException catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Top-up failed. Try again.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: ZSpacing.sm),
        decoration: BoxDecoration(
          color: ZColors.darkRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZColors.darkOutline),
        ),
        child: Text(
          label,
          style: ZTypography.captionStrong.copyWith(
            color: ZColors.accent,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final isCredit = switch (tx.type) {
      WalletTxType.topup || WalletTxType.credit || WalletTxType.refund => true,
      WalletTxType.debit || WalletTxType.payout || WalletTxType.adjustment =>
        false,
    };
    final isCashback = tx.note.toLowerCase().contains('cashback');
    final iconBg = isCashback
        ? ZColors.successTint
        : isCredit
            ? ZColors.successTint
            : ZColors.background;
    final iconColor = isCashback
        ? ZColors.dark
        : isCredit
            ? ZColors.success
            : ZColors.textSecondary;
    return ZListTile(
      title: tx.note,
      subtitle: ZFormat.dayDateTime(tx.createdAt.toLocal()),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          size: 18,
          color: iconColor,
        ),
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}${ZFormat.inr(tx.amountPaise)}',
        style: ZTypography.numeric.copyWith(
          color: isCredit ? ZColors.success : ZColors.textPrimary,
        ),
      ),
      showChevron: false,
    );
  }
}
