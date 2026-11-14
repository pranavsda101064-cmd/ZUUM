import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

/// Incoming-offer sheet with a live countdown, accept/decline and
/// server-error surfacing (expired / already taken).
class OfferSheet extends ConsumerStatefulWidget {
  const OfferSheet({super.key, required this.offer});

  final DriverOffer offer;

  @override
  ConsumerState<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<OfferSheet> {
  late int _secondsLeft;
  late final int _totalSeconds;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.offer.secondsLeft.clamp(0, 999);
    _totalSeconds = _secondsLeft == 0 ? 1 : _secondsLeft;
    if (_secondsLeft > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _secondsLeft = (_secondsLeft - 1).clamp(0, 999);
        });
        if (_secondsLeft == 0) {
          _ticker?.cancel();
          // Offer expired — dismiss without accepting.
          if (mounted && !_busy) Navigator.of(context).pop(false);
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(partnerApiProvider).acceptOffer(widget.offer.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not accept the trip. Try again.';
      });
    }
  }

  Future<void> _decline() async {
    try {
      await ref.read(partnerApiProvider).declineOffer(widget.offer.id);
    } catch (_) {
      // Best effort; the offer expires server-side anyway.
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final commission = (offer.farePaise * 20 / 100).round();
    final goodsSummary = offer.kind == OfferKind.goods
        ? [
            if (offer.goodsType != null) offer.goodsType!,
            if (offer.weightKg != null) '${offer.weightKg} kg',
            if (offer.needsLoadingHelp) 'Loading help',
          ].join(' · ')
        : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZSpacing.lg,
          0,
          ZSpacing.lg,
          ZSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const ZLiveDot(color: ZColors.highlight),
                const SizedBox(width: ZSpacing.sm),
                Text(
                  'NEW TRIP REQUEST',
                  style: ZTypography.overline.copyWith(letterSpacing: 0.6),
                ),
              ],
            ),
            const SizedBox(height: ZSpacing.md),
            ZOfferCard(
              serviceCategoryName: offer.serviceCategoryName,
              isGoods: offer.kind == OfferKind.goods,
              pickupAddress: offer.pickup.address ?? 'Pickup',
              dropAddress: offer.drop.address ?? 'Drop',
              distanceLabel: ZFormat.distance(offer.distanceM),
              pickupEtaLabel: ZFormat.duration(offer.pickupEtaS),
              farePaise: offer.farePaise,
              earningPaise: offer.farePaise - commission,
              surgeMultiplier: offer.surgeMultiplier,
              goodsSummary: goodsSummary,
              secondsLeft: _secondsLeft,
              totalSeconds: _totalSeconds,
              busy: _busy,
              onAccept: _accept,
              onDecline: _decline,
            ),
            if (_error != null) ...[
              const SizedBox(height: ZSpacing.sm),
              Container(
                padding: const EdgeInsets.all(ZSpacing.md),
                decoration: const BoxDecoration(
                  color: ZColors.errorTint,
                  borderRadius:
                      BorderRadius.all(Radius.circular(ZRadii.sm)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 18, color: ZColors.error),
                    const SizedBox(width: ZSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: ZTypography.caption
                            .copyWith(color: ZColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: ZSpacing.sm),
            Text(
              'Accept within $_secondsLeft s — trips go to the fastest '
              'captain.',
              style: ZTypography.overline.copyWith(
                color: ZColors.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
