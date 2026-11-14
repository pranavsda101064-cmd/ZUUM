import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuum_design_system/design_system.dart';

/// Safety centre — real helplines, SOS guidance, trip sharing tips.
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  static const _helplines = [
    ('112', 'Emergency Response Support System'),
    ('100', 'Police control room'),
    ('108', 'Ambulance'),
    ('1091', 'Women’s helpline'),
    ('1098', 'Child helpline'),
    ('1930', 'Cyber crime helpline'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Safety', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          ZCard(
            color: ZColors.errorTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: ZColors.error),
                    const SizedBox(width: ZSpacing.sm),
                    Text('In an emergency, call 112', style: ZTypography.titleMd),
                  ],
                ),
                const SizedBox(height: ZSpacing.sm),
                Text(
                  'Use the SOS button on your trip screen to alert Zuum Safety '
                  'and share your live trip with trusted contacts.',
                  style: ZTypography.body.copyWith(color: ZColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          Text('Helplines', style: ZTypography.overline),
          const SizedBox(height: ZSpacing.sm),
          for (final (number, label) in _helplines)
            ZListTile(
              title: number,
              subtitle: label,
              leading: const Icon(Icons.call_outlined, color: ZColors.error),
              onTap: () => _call(number),
            ),
          const Divider(indent: 16, endIndent: 16),
          const _TipRow(
            icon: Icons.share_location_outlined,
            title: 'Share your trip',
            body: 'Send live trip details to family while you travel.',
          ),
          const _TipRow(
            icon: Icons.pin_drop_outlined,
            title: 'Check the vehicle',
            body: 'Match the plate and model shown in the app before boarding.',
          ),
          const _TipRow(
            icon: Icons.support_agent_outlined,
            title: 'Report an issue',
            body: 'Every report is reviewed — use Help & support after your trip.',
          ),
        ],
      ),
    );
  }

  Future<void> _call(String number) async {
    try {
      await launchUrl(
        Uri.parse('tel:$number'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // No dialler available; the number is on screen.
    }
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZColors.primary),
          const SizedBox(width: ZSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: ZTypography.caption
                      .copyWith(color: ZColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
