import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

final _promosProvider = FutureProvider<List<PromoCampaign>>(
  (ref) => ref.watch(apiContractProvider).activePromos(),
);

/// Offers & referrals.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promos = ref.watch(_promosProvider);
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Offers & referrals', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          ZCard(
            color: ZColors.dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite friends to Zuum',
                  style: ZTypography.titleMd.copyWith(color: ZColors.onDark),
                ),
                const SizedBox(height: ZSpacing.xs),
                Text(
                  'You both get ₹50 when they take their first trip.',
                  style: ZTypography.caption.copyWith(color: ZColors.onDarkSecondary),
                ),
                const SizedBox(height: ZSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZSpacing.lg,
                          vertical: ZSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: ZColors.onDarkSecondary),
                          borderRadius: BorderRadius.circular(ZRadii.md),
                        ),
                        child: Text(
                          'ZUUM-RAVI-50',
                          style: ZTypography.numeric.copyWith(
                            color: ZColors.onDark,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ZSpacing.md),
                    ZIconButton(
                      icon: Icons.copy_rounded,
                      background: ZColors.accent,
                      foreground: ZColors.dark,
                      tooltip: 'Copy code',
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: 'ZUUM-RAVI-50'),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Referral code copied')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          Text('Active offers', style: ZTypography.overline),
          const SizedBox(height: ZSpacing.sm),
          promos.when(
            loading: () => const ZSkeletonList(itemCount: 2),
            error: (_, _) => ZErrorState(
              title: 'Could not load offers',
              message: 'Check your connection and try again.',
              onRetry: () => ref.invalidate(_promosProvider),
            ),
            data: (list) => Column(
              children: [
                for (final promo in list) ...[
                  ZCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: ZColors.highlightTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_offer_outlined,
                              color: ZColors.dark),
                        ),
                        const SizedBox(width: ZSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      promo.title,
                                      style: ZTypography.bodyStrong,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                promo.description,
                                style: ZTypography.caption
                                    .copyWith(color: ZColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: ZSpacing.sm),
                        ZBadge(
                          label: promo.code,
                          tone: ZBadgeTone.highlight,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
