import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_design_system/design_system.dart';

import 'booking_controller.dart';

/// Goods shipment details — Gemini spec §2k: three cards (contacts,
/// type & weight, handling), weight range pills, dimension inputs bound
/// to the vehicle envelope with a 1-tap upgrade guardrail, required
/// prohibited-items declaration.
class GoodsDetailsScreen extends ConsumerStatefulWidget {
  const GoodsDetailsScreen({super.key});

  @override
  ConsumerState<GoodsDetailsScreen> createState() => _GoodsDetailsScreenState();
}

class _GoodsDetailsScreenState extends ConsumerState<GoodsDetailsScreen> {
  static const _goodsTypes = [
    'Documents',
    'Food & Tiffin',
    'Electronics',
    'Furniture',
    'Apparel / Textiles',
    'Hardware / Spare Parts',
    'House Shifting',
  ];

  /// Vehicle envelopes (ft) — guardrail per spec §2k.
  static const _limits = <String, (double, double, double, int)>{
    'goods_2w': (1.5, 1.5, 1.5, 20),
    'goods_3w': (5, 3, 3, 500),
    'ace': (7, 4.5, 5, 750),
    'pickup': (8, 5, 5, 1200),
    'van': (8, 5, 6, 800),
    'tempo': (10, 5, 5, 2500),
  };
  static const _nextVehicle = <String, (String, String, String)>{
    'goods_2w': ('goods_3w', '3W Cargo', '+₹80'),
    'goods_3w': ('ace', 'Tata Ace', '+₹140'),
    'ace': ('pickup', 'Pickup 8ft', '+₹140'),
    'pickup': ('tempo', 'Tempo 407', '+₹180'),
    'van': ('tempo', 'Tempo 407', '+₹180'),
    'tempo': ('tempo', 'Tempo 407', ''),
  };

  String? _goodsType;
  String _weightRange = '50–200 kg';
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _senderName = TextEditingController();
  final _senderPhone = TextEditingController();
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  bool _loadingHelp = false;
  bool _fragile = false;
  bool _prohibited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final goods = ref.read(bookingControllerProvider).goods;
    if (goods != null) {
      _goodsType = goods.goodsType;
      _loadingHelp = goods.needsLoadingHelp;
      _senderName.text = goods.senderName ?? '';
      _senderPhone.text = goods.senderPhone ?? '';
      _receiverName.text = goods.receiverName ?? '';
      _receiverPhone.text = goods.receiverPhone ?? '';
      if (goods.weightKg != null) {
        _weightRange = switch (goods.weightKg!) {
          <= 50 => 'Up to 50 kg',
          <= 200 => '50–200 kg',
          <= 500 => '200–500 kg',
          _ => '500–750 kg',
        };
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _length,
      _width,
      _height,
      _senderName,
      _senderPhone,
      _receiverName,
      _receiverPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _weightKg => switch (_weightRange) {
        'Up to 50 kg' => 30,
        '50–200 kg' => 120,
        '200–500 kg' => 350,
        _ => 650,
      };

  /// Returns an upgrade hint when dimensions exceed the vehicle envelope.
  (String, String, String)? _guardrail() {
    final code = ref.read(bookingControllerProvider).selectedCategoryCode;
    if (code == null) return null;
    final limit = _limits[code];
    if (limit == null) return null;
    final l = double.tryParse(_length.text.trim());
    final w = double.tryParse(_width.text.trim());
    final h = double.tryParse(_height.text.trim());
    final exceeds = (l != null && l > limit.$1) ||
        (w != null && w > limit.$2) ||
        (h != null && h > limit.$3) ||
        _weightKg > limit.$4;
    if (!exceeds) return null;
    final next = _nextVehicle[code];
    if (next == null || next.$1 == code) return null;
    return next;
  }

  void _continue() {
    if (_goodsType == null) {
      setState(() => _error = 'Choose what you are sending');
      return;
    }
    if (_receiverName.text.trim().isEmpty || _receiverPhone.text.trim().isEmpty) {
      setState(() => _error = 'Receiver name and phone are required');
      return;
    }
    if (!_prohibited) {
      setState(() => _error = 'Confirm the prohibited-items declaration');
      return;
    }
    final dims = double.tryParse(_length.text.trim());
    ref.read(bookingControllerProvider.notifier).setGoods(
          GoodsDetails(
            goodsType: _goodsType,
            weightKg: _weightKg,
            dimensionsCuft: dims,
            needsLoadingHelp: _loadingHelp,
            senderName: _senderName.text.trim().isEmpty
                ? null
                : _senderName.text.trim(),
            senderPhone: _senderPhone.text.trim().isEmpty
                ? null
                : _senderPhone.text.trim(),
            receiverName: _receiverName.text.trim(),
            receiverPhone: _receiverPhone.text.trim(),
          ),
        );
    context.push('/booking/options');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingControllerProvider);
    final vehicleName = ref
            .watch(fareOptionsProvider)
            .value
            ?.where((o) => o.category.code == draft.selectedCategoryCode)
            .firstOrNull
            ?.category
            .name ??
        'vehicle';
    final upgrade = _guardrail();

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: 'Parcel & contact details',
        showBack: true,
        subtitle: draft.selectedCategoryCode != null ? vehicleName : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          // Card 1 — contacts.
          _SectionCard(
            overline: 'SENDER & RECEIVER',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(ZSpacing.md),
                  decoration: BoxDecoration(
                    color: ZColors.background,
                    borderRadius: BorderRadius.circular(ZRadii.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 10, color: ZColors.success),
                      const SizedBox(width: ZSpacing.sm),
                      Expanded(
                        child: Text(
                          'Sender: You (picking up from current location)',
                          style: ZTypography.captionStrong,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZSpacing.md),
                ZTextField(
                  controller: _senderName,
                  label: 'Sender name (optional)',
                  hint: 'Your full name',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: ZSpacing.lg),
                ZTextField(
                  controller: _senderPhone,
                  label: 'Sender mobile (optional)',
                  hint: '98450 12345',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: ZSpacing.lg),
                ZTextField(
                  controller: _receiverName,
                  label: 'Receiver name',
                  hint: 'e.g., Vishwanath Hardware',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: ZSpacing.lg),
                ZTextField(
                  controller: _receiverPhone,
                  label: 'Receiver mobile',
                  hint: '98450 12345',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: ZSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.sms_outlined,
                      size: 16,
                      color: ZColors.textSecondary,
                    ),
                    const SizedBox(width: ZSpacing.sm),
                    Expanded(
                      child: Text(
                        'Send live tracking & delivery OTP to receiver via SMS',
                        style: ZTypography.caption.copyWith(
                          color: ZColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),

          // Card 2 — goods type & weight.
          _SectionCard(
            overline: 'WHAT ARE YOU SENDING?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: ZSpacing.sm,
                  runSpacing: ZSpacing.sm,
                  children: [
                    for (final t in _goodsTypes)
                      ZChip(
                        label: t,
                        selected: _goodsType == t,
                        onTap: () => setState(() {
                          _goodsType = t;
                          // Spec: Furniture/Electronics auto-mark fragile.
                          if (t == 'Furniture' || t == 'Electronics') {
                            _fragile = true;
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: ZSpacing.lg),
                Row(
                  children: [
                    Text('Estimated weight', style: ZTypography.captionStrong),
                    const Spacer(),
                    Text(
                      'Max ${_limits[draft.selectedCategoryCode]?.$4 ?? 750} kg',
                      style: ZTypography.overline.copyWith(
                        color: ZColors.textSecondary,
                        letterSpacing: 0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpacing.sm),
                Wrap(
                  spacing: ZSpacing.sm,
                  children: [
                    for (final r in const [
                      'Up to 50 kg',
                      '50–200 kg',
                      '200–500 kg',
                      '500–750 kg',
                    ])
                      ZChip(
                        label: r,
                        selected: _weightRange == r,
                        onTap: () => setState(() => _weightRange = r),
                      ),
                  ],
                ),
                const SizedBox(height: ZSpacing.lg),
                Row(
                  children: [
                    _DimInput(
                      controller: _length,
                      label: 'L (ft)',
                      error: upgrade != null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(width: ZSpacing.sm),
                    _DimInput(
                      controller: _width,
                      label: 'W (ft)',
                      error: upgrade != null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(width: ZSpacing.sm),
                    _DimInput(
                      controller: _height,
                      label: 'H (ft)',
                      error: upgrade != null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                if (upgrade != null) ...[
                  const SizedBox(height: ZSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(ZSpacing.md),
                    decoration: BoxDecoration(
                      color: ZColors.errorTint,
                      borderRadius: BorderRadius.circular(ZRadii.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 18, color: ZColors.error),
                        const SizedBox(width: ZSpacing.sm),
                        Expanded(
                          child: Text(
                            'Dimensions exceed this vehicle. Switch to '
                            '${upgrade.$2} (${upgrade.$3}).',
                            style: ZTypography.captionStrong
                                .copyWith(color: ZColors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(bookingControllerProvider.notifier)
                                .selectCategory(upgrade.$1);
                            setState(() {
                              _length.clear();
                              _width.clear();
                              _height.clear();
                            });
                          },
                          child: const Text('Switch'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.lg),

          // Card 3 — handling & safety.
          _SectionCard(
            overline: 'HANDLING & SAFETY',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fragile item — handle with extra care',
                        style: ZTypography.captionStrong,
                      ),
                    ),
                    ZToggle(
                      value: _fragile,
                      onChanged: (v) => setState(() => _fragile = v),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Package contains no illegal, hazardous, or prohibited items',
                        style: ZTypography.caption.copyWith(
                          color: ZColors.textSecondary,
                        ),
                      ),
                    ),
                    ZToggle(
                      value: _prohibited,
                      onChanged: (v) => setState(() => _prohibited = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: ZSpacing.lg),
            Text(_error!,
                style: ZTypography.caption.copyWith(color: ZColors.error)),
          ],
          const SizedBox(height: ZSpacing.xxl),
          ZButton(
            label: 'Choose vehicle & see fare',
            onPressed: _continue,
          ),
          const SizedBox(height: ZSpacing.lg),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.overline, required this.child});

  final String overline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(overline, style: ZTypography.overline),
          const SizedBox(height: ZSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _DimInput extends StatelessWidget {
  const _DimInput({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.error = false,
  });

  final TextEditingController controller;
  final String label;
  final bool error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: onChanged,
          style: ZTypography.numeric,
          decoration: InputDecoration(
            labelText: label,
            errorText: error ? 'Over' : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ZSpacing.sm,
              vertical: ZSpacing.sm,
            ),
          ),
        ),
      ),
    );
  }
}
