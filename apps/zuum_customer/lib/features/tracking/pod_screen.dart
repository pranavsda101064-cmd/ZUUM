import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';

/// Proof-of-delivery — Gemini spec §2l: capture receiver + OTP + dual photo
/// evidence + signature, then a verified confirmation with Share POD Challan.
class PodScreen extends ConsumerStatefulWidget {
  const PodScreen({super.key});

  @override
  ConsumerState<PodScreen> createState() => _PodScreenState();
}

class _PodScreenState extends ConsumerState<PodScreen> {
  final _receiver = TextEditingController();
  final _otp = TextEditingController();
  final _signaturePoints = ValueNotifier<List<Offset>?>(null);
  final _signatureKey = GlobalKey();

  String? _pickupPhoto;
  String? _dropPhoto;
  DateTime? _pickupPhotoAt;
  DateTime? _dropPhotoAt;
  String? _error;
  bool _busy = false;
  bool _verified = false;
  Uint8List? _signaturePng;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    final booking = ref.read(activeBookingProvider);
    if (booking?.receiverName != null) {
      _receiver.text = booking!.receiverName!;
    }
  }

  @override
  void dispose() {
    _receiver.dispose();
    _otp.dispose();
    _signaturePoints.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool pickup}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (picked == null) return;
      setState(() {
        if (pickup) {
          _pickupPhoto = picked.path;
          _pickupPhotoAt = DateTime.now();
        } else {
          _dropPhoto = picked.path;
          _dropPhotoAt = DateTime.now();
        }
      });
    } catch (_) {
      // Camera unavailable (permissions/tests) — photos stay optional.
    }
  }

  Future<void> _captureSignature() async {
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      _signaturePng = bytes?.buffer.asUint8List();
    } catch (_) {
      // Signature capture is optional evidence; rasterization can be
      // unavailable (widget tests / unusual devices). Delivery confirmation
      // must never be blocked by it.
      _signaturePng = null;
    }
  }

  Future<void> _confirm() async {
    final booking = ref.read(activeBookingProvider);
    if (booking == null) return;
    final receiver = _receiver.text.trim();
    final otp = _otp.text.trim();
    if (receiver.isEmpty) {
      setState(() => _error = 'Enter the receiver’s name');
      return;
    }
    if (otp.length != 4) {
      setState(() => _error = 'Enter the 4-digit delivery OTP');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _captureSignature();
      await ref.read(apiContractProvider).verifyOtp(
            bookingId: booking.id,
            otp: otp,
          );
      String? signaturePath;
      if (_signaturePng != null) {
        final dir = await io.Directory.systemTemp.createTemp('zuum_pod');
        final file = io.File('${dir.path}/signature.png');
        await file.writeAsBytes(_signaturePng!, flush: true);
        signaturePath = file.path;
      }
      await ref.read(apiContractProvider).submitPod(
            bookingId: booking.id,
            receiverName: receiver,
            otp: otp,
            photoPath: _dropPhoto,
            signaturePath: signaturePath,
          );
      ref.read(podProofProvider.notifier).set(
            PodProof(
              pickupPhotoPath: _pickupPhoto,
              dropPhotoPath: _dropPhoto,
              pickupPhotoAt: _pickupPhotoAt,
              dropPhotoAt: _dropPhotoAt,
              signaturePng: _signaturePng,
              receiverName: receiver,
              otp: otp,
            ),
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _verified = true;
      });
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
        _error = 'Could not confirm delivery. Try again.';
      });
    }
  }

  void _continue() {
    context.pushReplacement('/booking/payment');
  }

  Future<void> _sharePod(Booking booking) async {
    final files = <XFile>[
      if (_pickupPhoto != null) XFile(_pickupPhoto!),
      if (_dropPhoto != null) XFile(_dropPhoto!),
    ];
    final text = 'Zuum POD Challan · ${booking.serviceCategoryName}\n'
        'Order #${booking.id}\n'
        '${booking.pickupAddress} → ${booking.dropAddress}\n'
        'Receiver: ${_receiver.text.trim()} · OTP verified\n'
        'Delivered ${ZFormat.shortDateTime(DateTime.now())}';
    await SharePlus.instance.share(
      ShareParams(text: text, files: files.isEmpty ? null : files),
    );
    if (mounted) setState(() => _shared = true);
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(activeBookingProvider);
    if (booking == null) {
      return Scaffold(
        backgroundColor: ZColors.background,
        appBar: const ZAppBar(title: 'Proof of delivery'),
        body: ZEmptyState(
          title: 'No delivery to confirm',
          subtitle: 'Completed goods trips appear here after drop-off.',
          actionLabel: 'Back to home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: 'Proof of delivery',
        subtitle: '#${booking.id}',
      ),
      body: _verified ? _buildVerified(booking) : _buildForm(booking),
      bottomNavigationBar: _verified
          ? _SafeBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: ZButton(
                      label: 'Report issue',
                      variant: ZButtonVariant.secondary,
                      onPressed: () => context.push('/support'),
                    ),
                  ),
                  const SizedBox(width: ZSpacing.md),
                  Expanded(
                    flex: 2,
                    child: ZButton(
                      label: _shared ? 'Shared ✓' : 'Share POD challan',
                      icon: _shared
                          ? Icons.check_rounded
                          : Icons.share_outlined,
                      onPressed: () => _sharePod(booking),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildForm(Booking booking) {
    return ListView(
      padding: const EdgeInsets.all(ZSpacing.lg),
      children: [
        Text(
          'Ask the receiver for the delivery OTP shown on their app/SMS.',
          style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        ),
        const SizedBox(height: ZSpacing.lg),
        ZTextField(
          controller: _receiver,
          label: 'Receiver name',
          hint: 'e.g., Vishwanath Hardware',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: ZSpacing.lg),
        ZTextField(
          controller: _otp,
          label: 'Delivery OTP',
          keyboardType: TextInputType.number,
          hint: '4-digit code',
        ),
        if (_error != null) ...[
          const SizedBox(height: ZSpacing.sm),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: ZColors.error),
              const SizedBox(width: ZSpacing.xs),
              Expanded(
                child: Text(
                  _error!,
                  style: ZTypography.captionStrong.copyWith(
                    color: ZColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: ZSpacing.xl),
        Text('PHOTO EVIDENCE', style: ZTypography.overline),
        const SizedBox(height: ZSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _PhotoSlot(
                label: 'Loaded',
                path: _pickupPhoto,
                onTap: () => _pickPhoto(pickup: true),
              ),
            ),
            const SizedBox(width: ZSpacing.sm),
            Expanded(
              child: _PhotoSlot(
                label: 'Unloaded',
                path: _dropPhoto,
                onTap: () => _pickPhoto(pickup: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZSpacing.xl),
        Text('RECEIVER SIGNATURE', style: ZTypography.overline),
        const SizedBox(height: ZSpacing.sm),
        Container(
          key: _signatureKey,
          height: 88,
          decoration: BoxDecoration(
            color: ZColors.background,
            borderRadius: BorderRadius.circular(ZRadii.sm),
            border: Border.all(color: ZColors.divider),
          ),
          child: GestureDetector(
            onPanUpdate: (d) {
              final points =
                  List<Offset>.from(_signaturePoints.value ?? const [])
                    ..add(d.localPosition);
              _signaturePoints.value = points;
            },
            onPanEnd: (_) => setState(() {}),
            child: ValueListenableBuilder<List<Offset>?>(
              valueListenable: _signaturePoints,
              builder: (context, points, _) => CustomPaint(
                painter: _SignaturePainter(points ?? const []),
                child: (points == null || points.isEmpty)
                    ? Center(
                        child: Text(
                          'Sign here',
                          style: ZTypography.caption.copyWith(
                            color: ZColors.textTertiary,
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZSpacing.xl),
        ZButton(
          label: 'Confirm delivery',
          loading: _busy,
          onPressed: _busy ? null : _confirm,
        ),
        const SizedBox(height: ZSpacing.lg),
      ],
    );
  }

  Widget _buildVerified(Booking booking) {
    final pod = ref.watch(podProofProvider);
    final receiver = pod?.receiverName ?? _receiver.text.trim();
    final deliveredAt = pod?.dropPhotoAt ?? DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(ZSpacing.lg),
      children: [
        // Verified banner.
        Container(
          padding: const EdgeInsets.all(ZSpacing.md),
          decoration: BoxDecoration(
            color: ZColors.successTint,
            borderRadius: BorderRadius.circular(ZRadii.md),
            border: Border.all(color: ZColors.success),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: ZColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 18, color: ZColors.onPrimary),
              ),
              const SizedBox(width: ZSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivered & OTP verified',
                        style: ZTypography.bodyStrong),
                    Text(
                      'Handed to $receiver at '
                      '${ZFormat.shortDateTime(deliveredAt)}',
                      style: ZTypography.caption.copyWith(
                        color: ZColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZSpacing.lg),

        // Dual photo evidence.
        ZCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PHOTO EVIDENCE', style: ZTypography.overline),
              const SizedBox(height: ZSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _EvidencePhoto(
                      path: pod?.pickupPhotoPath ?? _pickupPhoto,
                      caption: 'Loaded',
                      at: pod?.pickupPhotoAt ?? _pickupPhotoAt,
                    ),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  Expanded(
                    child: _EvidencePhoto(
                      path: pod?.dropPhotoPath ?? _dropPhoto,
                      caption: 'Unloaded',
                      at: pod?.dropPhotoAt ?? _dropPhotoAt,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZSpacing.lg),

        // Signature + metadata.
        ZCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('RECEIVER SIGNATURE & PIN',
                        style: ZTypography.overline),
                  ),
                  Text(
                    'OTP ${pod?.otp ?? _otp.text} verified ✓',
                    style: ZTypography.overline.copyWith(
                      color: ZColors.success,
                      letterSpacing: 0.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZSpacing.md),
              Container(
                height: 88,
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: ZSpacing.md),
                decoration: BoxDecoration(
                  color: ZColors.background,
                  borderRadius: BorderRadius.circular(ZRadii.sm),
                  border: Border.all(color: ZColors.divider),
                ),
                child: pod?.signaturePng != null
                    ? Image.memory(pod!.signaturePng!, height: 64)
                    : Text(
                        'No signature captured',
                        style: ZTypography.caption.copyWith(
                          color: ZColors.textTertiary,
                        ),
                      ),
              ),
              const SizedBox(height: ZSpacing.md),
              Text(
                '${booking.serviceCategoryName} · ${booking.id}\n'
                '${booking.pickupAddress} → ${booking.dropAddress}',
                style: ZTypography.overline.copyWith(
                  color: ZColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: ZSpacing.sm),
              Center(
                child: Text(
                  'ತಲುಪಿಸಲಾಗಿದೆ — ಸಂಪೂರ್ಣ ಭರವಸೆ',
                  style: ZTypography.kannada(
                    fontSize: 13,
                    color: ZColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZSpacing.xxl),

        // Single primary CTA — continue to payment.
        ZButton(
          label: 'Continue to payment',
          onPressed: _continue,
        ),
        const SizedBox(height: ZSpacing.lg),
      ],
    );
  }
}

class _SafeBottomBar extends StatelessWidget {
  const _SafeBottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        ZSpacing.lg,
        ZSpacing.lg,
        ZSpacing.lg,
        ZSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: ZColors.surface,
        border: Border(top: BorderSide(color: ZColors.divider)),
      ),
      child: child,
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.path,
    required this.onTap,
  });

  final String label;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: path == null ? ZColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(ZRadii.md),
          border: Border.all(color: ZColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: path != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (path != null)
                    Image.file(
                      io.File(path!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: ZColors.textTertiary),
                      ),
                    )
                  else
                    const SizedBox.expand(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZSpacing.sm,
                        vertical: ZSpacing.xs,
                      ),
                      color: ZColors.dark,
                      child: Text(
                        label,
                        style: ZTypography.overline.copyWith(
                          color: ZColors.onDark,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_camera_outlined,
                      color: ZColors.textTertiary),
                  const SizedBox(height: ZSpacing.xs),
                  Text(
                    label,
                    style: ZTypography.caption.copyWith(
                      color: ZColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EvidencePhoto extends StatelessWidget {
  const _EvidencePhoto({
    required this.path,
    required this.caption,
    required this.at,
  });

  final String? path;
  final String caption;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final time = at == null
        ? '—'
        : '${at!.hour.toString().padLeft(2, '0')}:'
            '${at!.minute.toString().padLeft(2, '0')}';
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: ZColors.background,
        borderRadius: BorderRadius.circular(ZRadii.md),
        border: Border.all(color: ZColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: path != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                if (path != null)
                  Image.file(
                    io.File(path!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: ZColors.textTertiary),
                    ),
                  )
                else
                  const SizedBox.expand(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZSpacing.sm,
                    ),
                    color: ZColors.dark,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$caption · $time',
                        style: ZTypography.overline.copyWith(
                          color: ZColors.onDark,
                          letterSpacing: 0.2,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                'No photo',
                style: ZTypography.caption.copyWith(
                  color: ZColors.textTertiary,
                ),
              ),
            ),
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
