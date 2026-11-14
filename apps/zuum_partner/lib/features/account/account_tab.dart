import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';

class NotificationsEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle(bool value) => state = value;
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabled, bool>(NotificationsEnabled.new);

/// Partner account: profile, KYC documents, rating, settings and sign-out.
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(partnerAuthProvider);
    final profile = auth.profile;
    final docs = ref.watch(partnerDocumentsProvider).value ?? const [];
    final notifications = ref.watch(notificationsEnabledProvider);

    if (profile == null) {
      return Scaffold(
        backgroundColor: ZColors.background,
        appBar: const ZAppBar(title: 'Account'),
        body: ListView(
          padding: const EdgeInsets.all(ZSpacing.lg),
          children: const [
            _ProfileSkeleton(),
            SizedBox(height: ZSpacing.md),
            Row(
              children: [
                Expanded(child: ZSkeleton(height: 112, radius: ZRadii.md)),
                SizedBox(width: ZSpacing.sm),
                Expanded(child: ZSkeleton(height: 112, radius: ZRadii.md)),
              ],
            ),
            SizedBox(height: ZSpacing.lg),
            ZSkeleton(width: 120, height: 14),
            SizedBox(height: ZSpacing.md),
            ZSkeleton(width: double.infinity, height: 64, radius: ZRadii.md),
            SizedBox(height: ZSpacing.sm),
            ZSkeleton(width: double.infinity, height: 64, radius: ZRadii.md),
          ],
        ),
      );
    }

    final docsByType = {for (final doc in docs) doc.type: doc};

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(
        title: 'Account',
        subtitle: 'Profile, documents and settings',
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZSpacing.lg),
            decoration: BoxDecoration(
              color: ZColors.surface,
              borderRadius: BorderRadius.circular(ZRadii.lg),
              border: Border.all(color: ZColors.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: ZColors.primaryTint,
                  child: Text(
                    profile.initials,
                    style: ZTypography.titleMd.copyWith(color: ZColors.primary),
                  ),
                ),
                const SizedBox(width: ZSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.fullName, style: ZTypography.titleMd),
                      const SizedBox(height: 2),
                      Text(
                        profile.email,
                        style: ZTypography.caption
                            .copyWith(color: ZColors.textSecondary),
                      ),
                      if (profile.phone != null)
                        Text(
                          profile.phone!,
                          style: ZTypography.caption
                              .copyWith(color: ZColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                ZStatusBadge(
                  label: profile.isApproved ? 'VERIFIED' : 'IN REVIEW',
                  tone: profile.isApproved
                      ? ZBadgeTone.success
                      : ZBadgeTone.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZStatCard(
                  label: 'Rating',
                  value: profile.ratingAvg.toStringAsFixed(1),
                  caption: '${profile.ratingCount} ratings',
                  icon: Icons.star_outline_rounded,
                  accent: true,
                ),
              ),
              const SizedBox(width: ZSpacing.sm),
              Expanded(
                child: ZStatCard(
                  label: 'Acceptance',
                  value: '${profile.acceptanceRate.toStringAsFixed(0)}%',
                  caption: 'Last 30 days',
                  icon: Icons.thumb_up_alt_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.lg),
          Row(
            children: [
              Text(
                'KYC documents',
                style: ZTypography.titleMd.copyWith(color: ZColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${profile.documentCount}/${profile.requiredDocumentCount}',
                style: ZTypography.caption
                    .copyWith(color: ZColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.sm),
          for (final type in const [
            KycDocType.licence,
            KycDocType.rc,
            KycDocType.insurance,
          ]) ...[
            ZDocumentTile(
              label: _docLabel(type),
              status: _docStatus(profile, docsByType[type]),
              fileName: docsByType[type]?.filePath == null
                  ? null
                  : 'On file',
              expiresAt: docsByType[type]?.expiresAt,
            ),
            const SizedBox(height: ZSpacing.sm),
          ],
          const SizedBox(height: ZSpacing.md),
          Text(
            'Settings',
            style: ZTypography.titleMd.copyWith(color: ZColors.textPrimary),
          ),
          const SizedBox(height: ZSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: ZColors.surface,
              borderRadius: BorderRadius.circular(ZRadii.lg),
              border: Border.all(color: ZColors.divider),
            ),
            child: Column(
              children: [
                ZListTile(
                  title: 'Trip notifications',
                  subtitle: 'Offers, reminders and payout updates',
                  leading: const Icon(Icons.notifications_outlined, size: 20),
                  showChevron: false,
                  trailing: Switch(
                    value: notifications,
                    onChanged: (value) => ref
                        .read(notificationsEnabledProvider.notifier)
                        .toggle(value),
                    activeTrackColor: ZColors.highlight,
                    inactiveTrackColor: ZColors.accent,
                  ),
                ),
                const ZDivider(),
                ZListTile(
                  title: 'Language',
                  subtitle: profile.languages.join(' · '),
                  leading: const Icon(Icons.translate_rounded, size: 20),
                  onTap: () => _showLanguage(context, ref, profile),
                ),
                const ZDivider(),
                ZListTile(
                  title: 'Help & support',
                  subtitle: 'Partner helpline · 24×7',
                  leading: const Icon(Icons.support_agent_outlined, size: 20),
                  onTap: () => _snack(
                    context,
                    'Call +91 80 4000 0000 or use in-app chat (Phase 2).',
                  ),
                ),
                const ZDivider(),
                ZListTile(
                  title: 'Terms & privacy',
                  subtitle: 'Partner agreement · version 1.0',
                  leading: const Icon(Icons.description_outlined, size: 20),
                  onTap: () =>
                      _snack(context, 'Full policy opens in the browser build.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: ZColors.surface,
              borderRadius: BorderRadius.circular(ZRadii.lg),
              border: Border.all(color: ZColors.divider),
            ),
            child: Column(
              children: [
                ZListTile(
                  title: 'Environment',
                  subtitle: 'Offers simulator active',
                  leading: const Icon(Icons.science_outlined, size: 20),
                  showChevron: false,
                  trailing: const ZBadge(label: 'MOCK'),
                ),
                const ZDivider(),
                const ZListTile(
                  title: 'App version',
                  subtitle: '1.0.0 · Partner build',
                  leading: Icon(Icons.info_outline_rounded, size: 20),
                  showChevron: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          ZButton(
            label: 'Sign out',
            variant: ZButtonVariant.danger,
            icon: Icons.logout_rounded,
            expand: true,
            onPressed: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: ZSpacing.lg),
          Text(
            'Zuum Partner · Mock build for the Phase 1 demo. No live payments '
            'or background location.',
            textAlign: TextAlign.center,
            style: ZTypography.overline.copyWith(color: ZColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _docLabel(KycDocType type) => switch (type) {
        KycDocType.licence => 'Driving licence',
        KycDocType.rc => 'Vehicle RC',
        KycDocType.insurance => 'Insurance',
        KycDocType.puc => 'PUC certificate',
        KycDocType.profilePhoto => 'Profile photo',
        KycDocType.vehiclePhoto => 'Vehicle photo',
      };

  ZDocStatus _docStatus(PartnerProfile profile, KycDocumentInfo? doc) {
    if (doc == null) return ZDocStatus.missing;
    if (doc.isExpired) return ZDocStatus.expired;
    if (profile.isApproved) return ZDocStatus.verified;
    return doc.status == KycStatus.approved
        ? ZDocStatus.verified
        : ZDocStatus.pending;
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLanguage(
    BuildContext context,
    WidgetRef ref,
    PartnerProfile profile,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Partner language'),
        children: [
          for (final language in profile.languages)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialog).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: ZSpacing.xs),
                child: Text(
                  language == profile.languages.first
                      ? '$language (default)'
                      : language,
                  style: ZTypography.body,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign out of Zuum Partner?'),
        content: const Text(
          'You will need your email and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              'Sign out',
              style: ZTypography.bodyStrong.copyWith(color: ZColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(partnerAuthProvider.notifier).signOut();
    }
  }
}


class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.lg),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
      ),
      child: const Row(
        children: [
          ZSkeleton(width: 56, height: 56, radius: 28),
          SizedBox(width: ZSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZSkeleton(width: 140, height: 16),
              SizedBox(height: 6),
              ZSkeleton(width: 190, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}
