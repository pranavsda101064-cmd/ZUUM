import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';

/// Rate & review after payment.
class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 5;
  final _tags = <String>{};
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Spec §2i: descriptors and tags switch with the rating band.
  List<String> _tagsFor(Booking booking, int rating) {
    if (rating >= 4) {
      return booking.isGoods
          ? const [
              'Careful handling',
              'On time',
              'Polite communication',
              'Clean vehicle',
            ]
          : const [
              'Polite communication',
              'Smooth driving',
              'Knew the shortcuts',
              'Clean vehicle',
              'Fair & honest',
            ];
    }
    return booking.isGoods
        ? const ['Damaged item', 'Late pickup', 'Rude behaviour']
        : const [
            'Asked for extra cash',
            'Rush driving',
            'Phone usage',
            'Route detour',
            'Vehicle condition',
          ];
  }

  String _descriptor(int rating) => switch (rating) {
        1 => 'Poor',
        2 => 'Below average',
        3 => 'Okay',
        4 => 'Good trip',
        _ => 'Superb! Namma Bengaluru’s finest',
      };

  Future<void> _submit(Booking booking) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiContractProvider).createReview(
            bookingId: booking.id,
            rating: _rating,
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            tags: _tags.toList(),
          );
      if (!mounted) return;
      context.pushReplacement('/booking/receipt');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit rating. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(activeBookingProvider);
    if (booking == null) {
      return Scaffold(
        backgroundColor: ZColors.background,
        appBar: const ZAppBar(title: 'Rate your trip'),
        body: ZEmptyState(
          title: 'Nothing to rate',
          subtitle: 'You can rate a trip right after it completes.',
          actionLabel: 'Back to home',
          onAction: () => context.go('/home'),
        ),
      );
    }
    final driverName = booking.driver?.name ?? 'your driver';

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: booking.isGoods ? 'Rate your delivery' : 'Rate your trip',
        showBack: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.xxl),
        children: [
          const SizedBox(height: ZSpacing.lg),
          Center(
            child: ZAvatar(
              initials: booking.driver?.name.isNotEmpty == true
                  ? booking.driver!.name.substring(0, 1)
                  : 'D',
              size: 72,
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          Center(
            child: Text(
              'How was the trip with $driverName?',
              style: ZTypography.titleLg,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          Center(
            child: ZRatingStars(
              rating: _rating.toDouble(),
              size: 40,
              onRate: (r) => setState(() {
                if (_rating != r) _tags.clear();
                _rating = r;
              }),
            ),
          ),
          const SizedBox(height: ZSpacing.sm),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey(_rating),
                children: [
                  Text(
                    _descriptor(_rating),
                    style: ZTypography.bodyStrong,
                    textAlign: TextAlign.center,
                  ),
                  if (_rating == 5) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ಸೂಪರ್ ಸವಾರಿ!',
                      style: ZTypography.kannada(
                        fontSize: 13,
                        color: ZColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          Wrap(
            spacing: ZSpacing.sm,
            runSpacing: ZSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final tag in _tagsFor(booking, _rating))
                ZChip(
                  label: tag,
                  selected: _tags.contains(tag),
                  onTap: () => setState(() {
                    if (!_tags.remove(tag)) _tags.add(tag);
                  }),
                ),
            ],
          ),
          const SizedBox(height: ZSpacing.xxl),
          ZTextField(
            controller: _comment,
            label: 'Tell us more (optional)',
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: ZSpacing.xxl),
          ZButton(
            label: 'Submit',
            loading: _busy,
            onPressed: _busy ? null : () => _submit(booking),
          ),
          TextButton(
            onPressed: () => context.pushReplacement('/booking/receipt'),
            child: Text(
              'Skip',
              style: ZTypography.bodyStrong.copyWith(color: ZColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
