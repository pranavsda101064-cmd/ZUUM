import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

/// Honest placeholder for routes whose real screens arrive in a later batch.
/// Never dressed up as a finished screen.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.illustration = 'empty_generic',
  });

  final String title;
  final String subtitle;
  final String illustration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(title: title),
      body: Column(
        children: [
          const SizedBox(height: ZSpacing.sm),
          const ZBadge(label: 'Coming soon'),
          Expanded(
            child: ZEmptyState(
              illustration: illustration,
              title: title,
              subtitle: subtitle,
            ),
          ),
        ],
      ),
    );
  }
}
