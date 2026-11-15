import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../fleet/fleet_controllers.dart';

/// Vehicle garage: availability toggles, insurance expiry warnings, add
/// vehicle, and the entry point to the fleet console.
class VehiclesTab extends ConsumerWidget {
  const VehiclesTab({super.key});

  static const _categories = [
    ('auto', 'Auto'),
    ('bike', 'Bike'),
    ('sedan', 'Sedan'),
    ('suv', 'SUV'),
    ('ace', 'Tata Ace'),
    ('pickup', 'Pickup'),
    ('van', 'Van'),
    ('tempo', 'Tempo'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(partnerVehiclesProvider);
    final fleet = ref.watch(fleetOverviewProvider);

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(
        title: 'Vehicles & fleet',
        subtitle: 'Availability, insurance and fleet console',
      ),
      body: RefreshIndicator(
        color: ZColors.primary,
        onRefresh: () async {
          ref.invalidate(partnerVehiclesProvider);
          ref.invalidate(fleetOverviewProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(ZSpacing.lg),
          children: [
            const ZPhotoHero(
              photo: 'blr_goods_auto',
              height: 110,
              caption: 'YOUR FLEET · BENGALURU',
            ),
            const SizedBox(height: ZSpacing.lg),
            Row(
              children: [
                Text(
                  'Your vehicles',
                  style: ZTypography.titleMd.copyWith(color: ZColors.textPrimary),
                ),
                const Spacer(),
                ZButton(
                  label: 'Add vehicle',
                  size: ZButtonSize.sm,
                  variant: ZButtonVariant.secondary,
                  icon: Icons.add_rounded,
                  expand: false,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    backgroundColor: ZColors.surface,
                    builder: (_) => const _AddVehicleSheet(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZSpacing.md),
            ...vehicles.when(
              loading: () => const [
                _VehicleSkeleton(),
                SizedBox(height: ZSpacing.sm),
                _VehicleSkeleton(),
              ],
              error: (error, _) => [
                ZEmptyState(
                  illustration: 'empty_generic',
                  title: 'Could not load vehicles',
                  subtitle: error is ApiException
                      ? error.message
                      : 'Pull down to retry.',
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      const ZEmptyState(
                        illustration: 'veh_auto',
                        title: 'No vehicles yet',
                        subtitle:
                            'Add a vehicle to start receiving trip requests.',
                      ),
                    ]
                  : [
                      for (final vehicle in list) ...[
                        _VehicleCard(vehicle: vehicle),
                        const SizedBox(height: ZSpacing.sm),
                      ],
                    ],
            ),
            const SizedBox(height: ZSpacing.lg),
            Container(
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
                      Text(
                        'FLEET CONSOLE',
                        style: ZTypography.overline.copyWith(
                          color: ZColors.accent,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      if (fleet.value != null)
                        Text(
                          '${fleet.value!.driversActive}/${fleet.value!.driversTotal} online',
                          style: ZTypography.overline.copyWith(
                            color: ZColors.onDarkSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: ZSpacing.sm),
                  Text(
                    'Run drivers and vehicles from one console',
                    style: ZTypography.titleMd.copyWith(color: ZColors.onDark),
                  ),
                  const SizedBox(height: ZSpacing.xs),
                  Text(
                    'Live availability, today\'s fleet earnings and vehicle '
                    'assignments.',
                    style: ZTypography.caption
                        .copyWith(color: ZColors.onDarkSecondary),
                  ),
                  const SizedBox(height: ZSpacing.md),
                  ZButton(
                    label: 'Open fleet console',
                    icon: Icons.groups_2_outlined,
                    variant: ZButtonVariant.secondary,
                    expand: true,
                    onPressed: () => context.push('/fleet'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpacing.lg),
            Text(
              'Keep insurance and permits current. Vehicles with expired '
              'documents are paused automatically.',
              style: ZTypography.overline.copyWith(color: ZColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends ConsumerStatefulWidget {
  const _VehicleCard({required this.vehicle});

  final PartnerVehicle vehicle;

  @override
  ConsumerState<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends ConsumerState<_VehicleCard> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(partnerApiProvider).setVehicleAvailability(
            vehicleId: widget.vehicle.id,
            isActive: value,
          );
      ref.invalidate(partnerVehiclesProvider);
      ref.invalidate(fleetOverviewProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZPlateBadge(plate: vehicle.registrationNumber),
              const SizedBox(width: ZSpacing.sm),
              ZStatusBadge(
                label: vehicle.isActive ? 'ACTIVE' : 'PAUSED',
                tone: vehicle.isActive
                    ? ZBadgeTone.success
                    : ZBadgeTone.neutral,
              ),
              const Spacer(),
              Switch(
                value: vehicle.isActive,
                onChanged: _busy ? null : _toggle,
                activeTrackColor: ZColors.primary,
                inactiveTrackColor: ZColors.accent,
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.sm),
          Row(
            children: [
              ZVehicleIcon(
                categoryCode: vehicle.categoryCode,
                width: 68,
                height: 44,
                semanticLabel: vehicle.categoryName,
              ),
              const SizedBox(width: ZSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.categoryName} · ${vehicle.displayName}',
                      style: ZTypography.bodyStrong,
                    ),
                    Text(
                      [
                        vehicle.color,
                        if (vehicle.seats != null) '${vehicle.seats} seats',
                        if (vehicle.capacityKg != null)
                          '${vehicle.capacityKg} kg',
                      ].join(' · '),
                      style: ZTypography.caption
                          .copyWith(color: ZColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (vehicle.insuranceExpiringSoon) ...[
            const SizedBox(height: ZSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: ZColors.error,
                ),
                const SizedBox(width: ZSpacing.xs),
                Text(
                  vehicle.insuranceExpiresAt == null
                      ? 'Insurance expiring soon'
                      : 'Insurance expires '
                          '${ZFormat.shortDate(vehicle.insuranceExpiresAt!)}',
                  style:
                      ZTypography.caption.copyWith(color: ZColors.error),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddVehicleSheet extends ConsumerStatefulWidget {
  const _AddVehicleSheet();

  @override
  ConsumerState<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends ConsumerState<_AddVehicleSheet> {
  static const _categories = VehiclesTab._categories;

  String? _category;
  final _regNo = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _regNo.dispose();
    _make.dispose();
    _model.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_category == null ||
        _regNo.text.trim().isEmpty ||
        _make.text.trim().isEmpty ||
        _model.text.trim().isEmpty ||
        _color.text.trim().isEmpty) {
      setState(() => _error = 'Fill in the category and vehicle details');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(partnerApiProvider).createVehicle(
            categoryCode: _category!,
            registrationNumber: _regNo.text,
            make: _make.text,
            model: _model.text,
            color: _color.text,
          );
      ref.invalidate(partnerVehiclesProvider);
      ref.invalidate(fleetOverviewProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not add the vehicle. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: ZSpacing.lg,
        right: ZSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + ZSpacing.lg,
      ),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Add a vehicle', style: ZTypography.titleMd),
            const SizedBox(height: ZSpacing.md),
            Wrap(
              spacing: ZSpacing.sm,
              runSpacing: ZSpacing.sm,
              children: [
                for (final (code, label) in _categories)
                  ZChip(
                    label: label,
                    selected: _category == code,
                    onTap: () => setState(() => _category = code),
                  ),
              ],
            ),
            const SizedBox(height: ZSpacing.md),
            ZTextField(
              controller: _regNo,
              label: 'Registration number',
              hint: 'KA 05 AB 1234',
            ),
            const SizedBox(height: ZSpacing.sm),
            ZTextField(controller: _make, label: 'Make'),
            const SizedBox(height: ZSpacing.sm),
            ZTextField(controller: _model, label: 'Model'),
            const SizedBox(height: ZSpacing.sm),
            ZTextField(controller: _color, label: 'Colour'),
            if (_error != null) ...[
              const SizedBox(height: ZSpacing.sm),
              Text(
                _error!,
                style: ZTypography.caption.copyWith(color: ZColors.error),
              ),
            ],
            const SizedBox(height: ZSpacing.md),
            ZButton(
              label: 'Save vehicle',
              icon: Icons.check_rounded,
              expand: true,
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}


/// Shimmer placeholder that mirrors the vehicle card geometry.
class _VehicleSkeleton extends StatelessWidget {
  const _VehicleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZSkeleton(width: 96, height: 24),
              SizedBox(width: ZSpacing.sm),
              ZSkeleton(width: 58, height: 18),
            ],
          ),
          SizedBox(height: ZSpacing.md),
          ZSkeleton(width: 180, height: 14),
          SizedBox(height: ZSpacing.sm),
          ZSkeleton(width: 120, height: 10),
        ],
      ),
    );
  }
}
