import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../notifications/notifications_screen.dart';

/// Account — Gemini spec §2o: profile identity card with rider rating
/// pill, Safety Toolkit card (priority), dashed coupon hub, grouped
/// settings list, danger logout, version + Kannada sign-off footer.
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You’ll need to log in again to book.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sign out',
              style: ZTypography.bodyStrong.copyWith(color: ZColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final unread = ref.watch(notificationsProvider).value?.results
            .where((n) => n.isUnread).length ??
        0;

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Account'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: ZSpacing.z48),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                ZSpacing.lg,
                ZSpacing.lg,
                ZSpacing.lg,
                0,
              ),
              child: ZPhotoHero(
                photo: 'blr_heritage_night',
                height: 140,
                caption: 'ZUUM · BENGALURU',
              ),
            ),
            // Profile identity card.
            Padding(
              padding: const EdgeInsets.all(ZSpacing.lg),
              child: ZCard(
                onTap: () => context.push('/settings/profile'),
                child: Row(
                  children: [
                    ZAvatar(initials: user?.initials ?? '?', size: 56),
                    const SizedBox(width: ZSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '—',
                            style: ZTypography.titleLg,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.phone ?? user?.email ?? '',
                            style: ZTypography.caption.copyWith(
                              color: ZColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ZColors.highlight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '★ 4.92 Rider',
                              style: ZTypography.overline.copyWith(
                                color: ZColors.dark,
                                letterSpacing: 0.2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: ZColors.textTertiary),
                  ],
                ),
              ),
            ),

            // Safety toolkit (high-priority block, spec §2o).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
              child: ZCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            color: ZColors.primary, size: 20),
                        const SizedBox(width: ZSpacing.sm),
                        Expanded(
                          child: Text(
                            'Safety toolkit & trusted contacts',
                            style: ZTypography.bodyStrong,
                          ),
                        ),
                        Text(
                          '2/3 added',
                          style: ZTypography.overline.copyWith(
                            color: ZColors.primary,
                            letterSpacing: 0.2,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZSpacing.xs),
                    Text(
                      'Auto-share night rides (10 PM–6 AM) and configure '
                      '1-tap 112 Police SOS.',
                      style: ZTypography.caption
                          .copyWith(color: ZColors.textSecondary),
                    ),
                    const SizedBox(height: ZSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: ZButton(
                            label: 'Trusted contacts',
                            variant: ZButtonVariant.secondary,
                            size: ZButtonSize.sm,
                            onPressed: () => context.push('/settings/trusted'),
                          ),
                        ),
                        const SizedBox(width: ZSpacing.sm),
                        Expanded(
                          child: ZButton(
                            label: 'SOS (112)',
                            variant: ZButtonVariant.danger,
                            size: ZButtonSize.sm,
                            onPressed: () => context.push('/safety'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZSpacing.lg),

            // Coupon hub.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
              child: ZCouponCard(
                code: 'NAMMA50',
                title: '50% off up to ₹40 on next Auto ride',
                savingsLabel: 'Save ₹40',
                actionLabel: 'View all',
                onAction: () => context.push('/offers'),
              ),
            ),

            const SizedBox(height: ZSpacing.lg),
            const _SectionLabel('Your data'),
            ZListTile(
              title: 'Saved addresses',
              leading: const Icon(Icons.bookmark_outline_rounded,
                  color: ZColors.textSecondary),
              onTap: () => context.push('/settings/addresses'),
            ),
            ZListTile(
              title: 'Payment methods',
              leading: const Icon(Icons.credit_card_outlined,
                  color: ZColors.textSecondary),
              onTap: () => context.push('/settings/payments'),
            ),
            ZListTile(
              title: 'Notifications & alerts',
              leading: const Icon(Icons.notifications_none_rounded,
                  color: ZColors.textSecondary),
              trailing: unread > 0
                  ? ZBadge(label: '$unread new', tone: ZBadgeTone.neutral)
                  : null,
              onTap: () => context.push('/notifications'),
            ),
            const Divider(indent: 16, endIndent: 16),
            const _SectionLabel('Support & business'),
            ZListTile(
              title: 'Help & support',
              subtitle: 'Lost item, fare dispute, parcel claim',
              leading: const Icon(Icons.support_agent_outlined,
                  color: ZColors.textSecondary),
              onTap: () => context.push('/support'),
            ),
            ZListTile(
              title: 'Business GST details',
              subtitle: 'Add GSTIN for B2B goods transport invoices',
              leading: const Icon(Icons.receipt_long_outlined,
                  color: ZColors.textSecondary),
              onTap: () => context.push('/settings/gst'),
            ),
            ZListTile(
              title: 'Settings',
              subtitle: 'English (ನಮ್ಮ ಕನ್ನಡ accents) · Default mode: Ride',
              leading: const Icon(Icons.settings_outlined,
                  color: ZColors.textSecondary),
              onTap: () => context.push('/settings'),
            ),
            const Divider(indent: 16, endIndent: 16),

            // Danger logout.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpacing.lg,
                ZSpacing.lg,
                ZSpacing.lg,
                ZSpacing.md,
              ),
              child: ZButton(
                label: 'Log out',
                variant: ZButtonVariant.secondary,
                onPressed: () => _confirmSignOut(context, ref),
              ),
            ),
            Center(
              child: Column(
                children: [
                  Text(
                    'Zuum v0.1.0 · Made in Bengaluru',
                    style: ZTypography.overline.copyWith(
                      color: ZColors.textTertiary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ಹಳೆ ಬೆಂಗಳೂರಿನ ಆತ್ಮ. ಹೊಸ ಬೆಂಗಳೂರಿನ ವೇಗ.',
                    style: ZTypography.kannada(
                      fontSize: 13,
                      color: ZColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZSpacing.lg,
        ZSpacing.lg,
        ZSpacing.lg,
        ZSpacing.xs,
      ),
      child: Text(text, style: ZTypography.overline),
    );
  }
}
