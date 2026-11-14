import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';

/// Holds the partner while KYC is under review. The mock build auto-approves
/// after a few seconds; the router moves the partner to the shell as soon as
/// the profile flips to approved.
class KycPendingScreen extends ConsumerStatefulWidget {
  const KycPendingScreen({super.key});

  @override
  ConsumerState<KycPendingScreen> createState() => _KycPendingScreenState();
}

class _KycPendingScreenState extends ConsumerState<KycPendingScreen> {
  Timer? _poll;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Review polling: cheap profile re-fetch; the router reacts to approval.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _refreshing) return;
      await ref.read(partnerAuthProvider.notifier).refreshProfile();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refreshNow() async {
    setState(() => _refreshing = true);
    ref.invalidate(partnerDocumentsProvider);
    ref.invalidate(partnerVehiclesProvider);
    await ref.read(partnerAuthProvider.notifier).refreshProfile();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(partnerAuthProvider).profile;
    final docs = ref.watch(partnerDocumentsProvider).value?.length ?? 0;
    final vehicles = ref.watch(partnerVehiclesProvider).value?.length ?? 0;

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: 'Verification',
        subtitle: profile?.fullName,
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZSpacing.xxl),
            decoration: BoxDecoration(
              color: ZColors.dark,
              borderRadius: BorderRadius.circular(ZRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: ZColors.highlight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: ZColors.dark, size: 22),
                ),
                const SizedBox(height: ZSpacing.lg),
                Text(
                  'Verification in progress',
                  style: ZTypography.titleMd.copyWith(color: ZColors.onDark),
                ),
                const SizedBox(height: ZSpacing.xs),
                Text(
                  'The Zuum ops team is reviewing your documents and vehicle. '
                  'You can go online as soon as you are approved.',
                  style: ZTypography.caption.copyWith(
                    color: ZColors.onDarkSecondary,
                  ),
                ),
                const SizedBox(height: ZSpacing.md),
                Text(
                  'ಪರಿಶೀಲನೆ ನಡೆಯುತ್ತಿದೆ',
                  style: ZTypography.kannada(
                    fontSize: 13,
                    color: ZColors.highlight,
                  ),
                ),
                const SizedBox(height: ZSpacing.sm),
                const ZBadge(
                  label: 'Mock build · auto-approves in ~3 s',
                  tone: ZBadgeTone.highlight,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          ZCard(
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.description_outlined,
                  label: 'Documents submitted',
                  value: '$docs',
                ),
                const Divider(height: 1),
                _SummaryRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Vehicles added',
                  value: '$vehicles',
                ),
                const Divider(height: 1),
                _SummaryRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Status',
                  value: profile?.kycStatus.name.toUpperCase() ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          ZButton(
            label: 'Refresh status',
            variant: ZButtonVariant.secondary,
            loading: _refreshing,
            onPressed: _refreshing ? null : _refreshNow,
          ),
          const SizedBox(height: ZSpacing.md),
          Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(partnerAuthProvider.notifier).signOut(),
              child: Text(
                'Sign out',
                style: ZTypography.bodyStrong.copyWith(
                  color: ZColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ZColors.textSecondary),
          const SizedBox(width: ZSpacing.md),
          Expanded(child: Text(label, style: ZTypography.body)),
          Text(value, style: ZTypography.numeric),
        ],
      ),
    );
  }
}
