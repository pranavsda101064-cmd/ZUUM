import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import 'navigation_screen.dart';
import 'trip_controllers.dart';

/// Partner trip lifecycle: navigate → arrive → customer OTP → in-trip →
/// POD (goods) → complete. Server-authoritative at every step.
class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  final _otp = TextEditingController();
  final _receiver = TextEditingController();
  final _signatureKey = GlobalKey();
  final _signature = ValueNotifier<List<Offset>>([]);
  String? _podPhoto;
  bool _busy = false;
  bool _deliveryVerified = false;
  String? _error;

  @override
  void dispose() {
    _otp.dispose();
    _receiver.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() body, {String? action}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
      _otp.clear();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '${action ?? 'Action'} failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _arrive() => _run(
        () => ref.read(tripControllerProvider.notifier).arrive(),
        action: 'Arrival update',
      );

  void _start() {
    final otp = _otp.text.trim();
    if (otp.isEmpty) {
      setState(() => _error = 'Enter the customer OTP to start');
      return;
    }
    _run(
      () => ref.read(tripControllerProvider.notifier).start(otp),
      action: 'OTP verification',
    );
  }

  Future<void> _verifyDelivery() async {
    final otp = _otp.text.trim();
    if (otp.isEmpty) {
      setState(() => _error = 'Enter the delivery OTP');
      return;
    }
    await _run(() async {
      await ref.read(tripControllerProvider.notifier).verifyDelivery(otp);
      if (mounted) setState(() => _deliveryVerified = true);
    }, action: 'Delivery verification');
  }

  Future<void> _pickPodPhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take delivery photo'),
              onTap: () => Navigator.of(sheet).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheet).pop('gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source:
            choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _podPhoto = picked.path);
    } catch (_) {
      setState(() => _error = 'Could not open the camera/gallery.');
    }
  }

  Future<String?> _signatureFile() async {
    if (_signature.value.isEmpty) return null;
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final dir = await io.Directory.systemTemp.createTemp('zuum_partner_pod');
      final file = io.File('${dir.path}/signature.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  void _complete(PartnerTrip trip) {
    if (trip.kind == OfferKind.goods) {
      if (_receiver.text.trim().isEmpty) {
        setState(() => _error = 'Enter the receiver name');
        return;
      }
    }
    _run(() async {
      if (trip.kind == OfferKind.goods) {
        final signaturePath = await _signatureFile();
        await ref.read(partnerApiProvider).uploadDeliveryPod(
              bookingId: trip.bookingId,
              receiverName: _receiver.text.trim(),
              photoPath: _podPhoto,
              signaturePath: signaturePath,
            );
      }
      await ref.read(tripControllerProvider.notifier).complete();
    }, action: 'Completion');
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Why cancel this trip?'),
        children: [
          for (final option in const [
            'Customer not reachable',
            'Vehicle issue',
            'Emergency',
            'Other',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialog).pop(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: ZSpacing.xs),
                child: Text(option, style: ZTypography.body),
              ),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref.read(tripControllerProvider.notifier).cancel(reason),
      action: 'Cancel',
    );
    if (mounted) context.go('/home');
  }

  void _call() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Calls the customer from a masked number (mock build).'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripControllerProvider);
    final trip = tripAsync.value;

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: trip == null ? 'Trip' : 'Trip · ${trip.serviceCategoryName}',
        subtitle: trip == null ? null : _stageLabel(trip),
        showBack: true,
        onBack: () => context.go('/home'),
        actions: [
          ZIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(tripControllerProvider),
          ),
        ],
      ),
      body: tripAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ZColors.primary),
        ),
        error: (error, _) => ZEmptyState(
          illustration: 'empty_generic',
          title: 'Could not load the trip',
          subtitle: error is ApiException
              ? error.message
              : 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(tripControllerProvider),
        ),
        data: (trip) => trip == null
            ? ZEmptyState(
                illustration: 'empty_generic',
                title: 'No active trip',
                subtitle:
                    'Go online on the home tab to receive your next request.',
                actionLabel: 'Back to home',
                onAction: () => context.go('/home'),
              )
            : AnimatedSwitcher(
                duration: ZMotion.base,
                switchInCurve: ZMotion.standard,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: trip.status == PartnerTripStatus.completed
                    ? _CompletedView(
                        key: ValueKey('done-${trip.bookingId}'),
                        trip: trip,
                      )
                    : KeyedSubtree(
                        key: ValueKey(trip.status),
                        child: _body(trip),
                      ),
              ),
      ),
    );
  }

  Widget _body(PartnerTrip trip) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          _StatusHeader(trip: trip),
          if (trip.route != null && trip.route!.geometry.length > 1) ...[
            const SizedBox(height: ZSpacing.md),
            _RoutePreview(trip: trip),
          ],
          const SizedBox(height: ZSpacing.md),
          _CustomerRow(trip: trip, onCall: _call),
          const SizedBox(height: ZSpacing.md),
          _RouteCard(trip: trip),
          if (trip.kind == OfferKind.goods && trip.goodsType != null) ...[
            const SizedBox(height: ZSpacing.md),
            _GoodsCard(trip: trip),
          ],
          const SizedBox(height: ZSpacing.lg),
          ..._flow(trip),
        ],
      ),
    );
  }

  Future<void> _openNavigation(PartnerTrip trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartnerNavigationScreen(trip: trip),
      ),
    );
    if (mounted) ref.invalidate(tripControllerProvider);
  }

  List<Widget> _flow(PartnerTrip trip) {
    switch (trip.status) {
      case PartnerTripStatus.assigned:
        return [
          ZButton(
            label: 'Arrived at pickup',
            icon: Icons.place_outlined,
            expand: true,
            loading: _busy,
            onPressed: _arrive,
          ),
          const SizedBox(height: ZSpacing.sm),
          ZButton(
            label: 'Navigate to pickup',
            icon: Icons.navigation_rounded,
            variant: ZButtonVariant.secondary,
            expand: true,
            onPressed: () => _openNavigation(trip),
          ),
          const SizedBox(height: ZSpacing.sm),
          ZButton(
            label: 'Cancel trip',
            variant: ZButtonVariant.ghost,
            expand: true,
            onPressed: _busy ? null : _cancel,
          ),
        ];

      case PartnerTripStatus.arrived:
        return [
          Text(
            'Ask ${trip.customerFirstName ?? 'the customer'} for the trip OTP',
            style: ZTypography.bodyStrong,
          ),
          const SizedBox(height: ZSpacing.sm),
          ZTextField(
            controller: _otp,
            label: 'Trip OTP',
            hint: '4-digit OTP',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          if (trip.devOtpHint != null) _devOtpHint(trip),
          const SizedBox(height: ZSpacing.md),
          ZButton(
            label: 'Start trip',
            icon: Icons.play_arrow_rounded,
            expand: true,
            loading: _busy,
            onPressed: _start,
          ),
          const SizedBox(height: ZSpacing.sm),
          ZButton(
            label: 'Navigate to pickup',
            icon: Icons.navigation_rounded,
            variant: ZButtonVariant.secondary,
            expand: true,
            onPressed: () => _openNavigation(trip),
          ),
          if (_error != null) _errorBanner(_error!),
          const SizedBox(height: ZSpacing.sm),
          ZButton(
            label: 'Cancel trip',
            variant: ZButtonVariant.ghost,
            expand: true,
            onPressed: _busy ? null : _cancel,
          ),
        ];

      case PartnerTripStatus.inProgress:
        final goods = trip.kind == OfferKind.goods;
        if (goods && !_deliveryVerified) {
          return [
            Text(
              'Collect the delivery OTP to close this POD trip',
              style: ZTypography.bodyStrong,
            ),
            const SizedBox(height: ZSpacing.sm),
            ZTextField(
              controller: _otp,
              label: 'Delivery OTP',
              hint: '4-digit OTP',
              keyboardType: TextInputType.number,
              prefixIcon: Icons.verified_outlined,
            ),
            if (trip.devOtpHint != null) _devOtpHint(trip),
            const SizedBox(height: ZSpacing.md),
            ZButton(
              label: 'Verify delivery OTP',
              icon: Icons.verified_rounded,
              expand: true,
              loading: _busy,
              onPressed: _verifyDelivery,
            ),
            if (_error != null) _errorBanner(_error!),
          ];
        }
        return [
          if (goods) ..._goodProofSection(),
          ZCommissionBreakdown(
            farePaise: trip.farePaise,
            commissionPaise: trip.commissionPaise,
            earningPaise: trip.earningPaise,
          ),
          const SizedBox(height: ZSpacing.md),
          ZButton(
            label: goods ? 'Complete delivery' : 'Complete trip',
            icon: Icons.check_rounded,
            expand: true,
            loading: _busy,
            onPressed: () => _complete(trip),
          ),
          const SizedBox(height: ZSpacing.sm),
          ZButton(
            label: goods ? 'Navigate delivery' : 'Navigate to drop',
            icon: Icons.navigation_rounded,
            variant: ZButtonVariant.secondary,
            expand: true,
            onPressed: () => _openNavigation(trip),
          ),
          if (_error != null) _errorBanner(_error!),
        ];

      case PartnerTripStatus.completed:
      case PartnerTripStatus.cancelled:
        return const [];
    }
  }

  List<Widget> _goodProofSection() {
    return [
      Text('Delivery proof', style: ZTypography.bodyStrong),
      const SizedBox(height: ZSpacing.sm),
      ZTextField(
        controller: _receiver,
        label: 'Receiver name',
        hint: 'Who accepted the goods?',
        prefixIcon: Icons.person_outline_rounded,
      ),
      const SizedBox(height: ZSpacing.sm),
      Row(
        children: [
          Expanded(
            child: ZButton(
              label: _podPhoto == null ? 'Add delivery photo' : 'Photo attached',
              icon: _podPhoto == null
                  ? Icons.add_a_photo_outlined
                  : Icons.check_circle_outline_rounded,
              variant: ZButtonVariant.secondary,
              size: ZButtonSize.sm,
              onPressed: _pickPodPhoto,
            ),
          ),
        ],
      ),
      const SizedBox(height: ZSpacing.sm),
      Row(
        children: [
          Text(
            'Signature (optional)',
            style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _signature.value = [],
            child: const Text('Clear'),
          ),
        ],
      ),
      RepaintBoundary(
        key: _signatureKey,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: ZColors.surface,
            borderRadius: BorderRadius.circular(ZRadii.md),
            border: Border.all(color: ZColors.divider),
          ),
          child: _SignaturePad(notifier: _signature),
        ),
      ),
      const SizedBox(height: ZSpacing.md),
    ];
  }

  Widget _devOtpHint(PartnerTrip trip) {
    return Padding(
      padding: const EdgeInsets.only(top: ZSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZSpacing.sm),
        decoration: const BoxDecoration(
          color: ZColors.highlightTint,
          borderRadius: BorderRadius.all(Radius.circular(ZRadii.sm)),
        ),
        child: Text(
          'DEV · demo OTP ${trip.devOtpHint}',
          style: ZTypography.overline.copyWith(
            color: ZColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(top: ZSpacing.sm),
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: const BoxDecoration(
        color: ZColors.errorTint,
        borderRadius: BorderRadius.all(Radius.circular(ZRadii.sm)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: ZColors.error),
          const SizedBox(width: ZSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: ZTypography.caption.copyWith(color: ZColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

String _stageLabel(PartnerTrip trip) => switch (trip.status) {
      PartnerTripStatus.assigned => 'Heading to pickup',
      PartnerTripStatus.arrived => 'At pickup',
      PartnerTripStatus.inProgress =>
        trip.kind == OfferKind.goods ? 'Delivering goods' : 'On the way',
      PartnerTripStatus.completed => 'Completed',
      PartnerTripStatus.cancelled => 'Cancelled',
    };

String _stageBadge(PartnerTrip trip) => switch (trip.status) {
      PartnerTripStatus.assigned => 'ASSIGNED',
      PartnerTripStatus.arrived => 'ARRIVED',
      PartnerTripStatus.inProgress => 'ON TRIP',
      PartnerTripStatus.completed => 'COMPLETED',
      PartnerTripStatus.cancelled => 'CANCELLED',
    };

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.trip});

  final PartnerTrip trip;

  @override
  Widget build(BuildContext context) {
    final hint = switch (trip.status) {
      PartnerTripStatus.assigned =>
        'Navigate to the pickup point, then mark yourself arrived.',
      PartnerTripStatus.arrived =>
        'Verify the trip OTP to start the journey.',
      PartnerTripStatus.inProgress => trip.kind == OfferKind.goods
          ? 'Deliver the goods and verify the delivery OTP.'
          : 'Drive the customer to the drop point safely.',
      PartnerTripStatus.completed => 'Payment settled.',
      PartnerTripStatus.cancelled => 'Trip cancelled.',
    };

    return Container(
      padding: const EdgeInsets.all(ZSpacing.lg),
      decoration: BoxDecoration(
        color: ZColors.dark,
        borderRadius: BorderRadius.circular(ZRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZLiveDot(
                color: trip.status == PartnerTripStatus.completed
                    ? ZColors.success
                    : ZColors.highlight,
              ),
              const SizedBox(width: ZSpacing.sm),
              Text(
                _stageBadge(trip),
                style: ZTypography.overline.copyWith(
                  color: ZColors.highlight,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                ZFormat.inr(trip.earningPaise),
                style: ZTypography.numeric.copyWith(color: ZColors.accent),
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.md),
          Text(
            _stageLabel(trip),
            style: ZTypography.titleLg.copyWith(color: ZColors.onDark),
          ),
          const SizedBox(height: ZSpacing.xs),
          Text(
            hint,
            style: ZTypography.caption.copyWith(color: ZColors.onDarkSecondary),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.trip, required this.onCall});

  final PartnerTrip trip;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final name = trip.customerFirstName ?? 'Customer';
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ZColors.primaryTint,
            child: Text(
              name.characters.first.toUpperCase(),
              style: ZTypography.bodyStrong.copyWith(color: ZColors.primary),
            ),
          ),
          const SizedBox(width: ZSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: ZTypography.bodyStrong),
                if (trip.customerPhoneMasked != null)
                  Text(
                    trip.customerPhoneMasked!,
                    style: ZTypography.caption
                        .copyWith(color: ZColors.textSecondary),
                  ),
              ],
            ),
          ),
          ZBadge(label: trip.paymentMethod.name.toUpperCase()),
          const SizedBox(width: ZSpacing.xs),
          ZIconButton(
            icon: Icons.call_outlined,
            tooltip: 'Call customer',
            onPressed: onCall,
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.trip});

  final PartnerTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
      ),
      child: ZRouteTimeline(
        pickup: trip.pickup.address ?? 'Pickup',
        drop: trip.drop.address ?? 'Drop',
        trailing: Text(
          ZFormat.inr(trip.farePaise),
          style: ZTypography.numeric.copyWith(fontSize: 13),
        ),
      ),
    );
  }
}

class _GoodsCard extends StatelessWidget {
  const _GoodsCard({required this.trip});

  final PartnerTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.highlightTint,
        borderRadius: BorderRadius.circular(ZRadii.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: ZColors.textSecondary),
          const SizedBox(width: ZSpacing.sm),
          Expanded(
            child: Text(
              [
                trip.goodsType ?? 'Goods',
                if (trip.needsLoadingHelp) 'Loading help required',
              ].join(' · '),
              style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({super.key, required this.trip});

  final PartnerTrip trip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          const SizedBox(height: ZSpacing.lg),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 620),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: ZColors.successTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: ZColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          Text(
            'Trip completed',
            textAlign: TextAlign.center,
            style: ZTypography.titleLg,
          ),
          const SizedBox(height: ZSpacing.xs),
          Text(
            '${trip.serviceCategoryName} · ${trip.bookingId.toUpperCase()}',
            textAlign: TextAlign.center,
            style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
          ),
          const SizedBox(height: ZSpacing.xl),
          ZCommissionBreakdown(
            farePaise: trip.farePaise,
            commissionPaise: trip.commissionPaise,
            earningPaise: trip.earningPaise,
          ),
          const SizedBox(height: ZSpacing.lg),
          ZButton(
            label: 'Back to home',
            icon: Icons.home_outlined,
            expand: true,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}


class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.trip});

  final PartnerTrip trip;

  @override
  Widget build(BuildContext context) {
    final route = trip.route!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ZRadii.lg),
      child: SizedBox(
        height: 160,
        child: ZMapView(
          center: ZMapCenter(trip.pickup.lat, trip.pickup.lng),
          interactive: false,
          showAttribution: false,
          route: ZMapRoute(
            [for (final point in route.geometry) ZMapCenter(point.lat, point.lng)],
            color: ZColors.highlight,
          ),
          markers: [
            ZMapMarker(trip.pickup.lat, trip.pickup.lng, kind: ZMapMarkerKind.pickup),
            ZMapMarker(
              trip.drop.lat,
              trip.drop.lng,
              color: ZColors.error,
              kind: ZMapMarkerKind.drop,
            ),
          ],
        ),
      ),
    );
  }
}


class _SignaturePad extends StatelessWidget {
  const _SignaturePad({required this.notifier});

  final ValueNotifier<List<Offset>> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Offset>>(
      valueListenable: notifier,
      builder: (context, points, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            notifier.value = [...points, details.localPosition];
          },
          onPanUpdate: (details) {
            notifier.value = [...notifier.value, details.localPosition];
          },
          child: CustomPaint(
            painter: _SignaturePainter(points),
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'Sign here',
                      style: TextStyle(color: ZColors.textTertiary, fontSize: 12),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = ZColors.dark
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}
