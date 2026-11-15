import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import 'fleet_controllers.dart';

/// Fleet console: live overview, driver roster and vehicle assignment.
class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(fleetOverviewProvider);
    final drivers = ref.watch(fleetDriversProvider);

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: 'Fleet console',
        subtitle: 'Mock org · live roster',
        showBack: true,
        actions: [
          ZIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(fleetOverviewProvider);
              ref.invalidate(fleetDriversProvider);
              ref.invalidate(fleetVehiclesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: ZColors.primary,
        onRefresh: () async {
          ref.invalidate(fleetOverviewProvider);
          ref.invalidate(fleetDriversProvider);
          ref.invalidate(fleetVehiclesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(ZSpacing.lg),
          children: [
            const ZPhotoHero(
              photo: 'blr_goods_truck',
              height: 110,
              caption: 'FLEET CONSOLE · BENGALURU',
            ),
            const SizedBox(height: ZSpacing.lg),
            overview.when(
              loading: () => const _FleetStatsSkeleton(),
              error: (error, _) => ZEmptyState(
                illustration: 'empty_generic',
                title: 'Could not load the fleet',
                subtitle: error is ApiException
                    ? error.message
                    : 'Pull down to retry.',
              ),
              data: (data) => Row(
                children: [
                  Expanded(
                    child: ZStatCard(
                      label: 'Drivers online',
                      value: '${data.driversActive}/${data.driversTotal}',
                      caption: 'Available now',
                      icon: Icons.groups_2_outlined,
                      accent: true,
                    ),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  Expanded(
                    child: ZStatCard(
                      label: 'Utilisation',
                      value: '${(data.utilisation * 100).round()}%',
                      caption: 'On trips vs online',
                      icon: Icons.speed_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpacing.sm),
            overview.maybeWhen(
              data: (data) => Row(
                children: [
                  Expanded(
                    child: ZStatCard(
                      label: 'Fleet earnings',
                      value: ZFormat.inr(data.earningsTodayPaise, compact: true),
                      caption: 'Today',
                      icon: Icons.currency_rupee_rounded,
                    ),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  Expanded(
                    child: ZStatCard(
                      label: 'Vehicles active',
                      value: '${data.vehiclesActive}/${data.vehiclesTotal}',
                      caption: 'Ready to dispatch',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: ZSpacing.lg),
            const ZSectionHeader(
              title: 'Drivers',
              caption: 'Live roster · tap to assign a vehicle',
            ),
            ...drivers.when(
              loading: () => const [
                _DriverSkeleton(),
                SizedBox(height: ZSpacing.sm),
                _DriverSkeleton(),
                SizedBox(height: ZSpacing.sm),
                _DriverSkeleton(),
              ],
              error: (error, _) => [
                ZEmptyState(
                  illustration: 'empty_generic',
                  title: 'Could not load drivers',
                  subtitle: error is ApiException
                      ? error.message
                      : 'Pull down to retry.',
                ),
              ],
              data: (list) => [
                for (final driver in list) ...[
                  _DriverCard(driver: driver),
                  const SizedBox(height: ZSpacing.sm),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends ConsumerStatefulWidget {
  const _DriverCard({required this.driver});

  final FleetDriver driver;

  @override
  ConsumerState<_DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends ConsumerState<_DriverCard> {
  Future<void> _assign() async {
    final vehicles = await ref.read(fleetVehiclesProvider.future);
    if (!mounted) return;
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a vehicle before assigning one.')),
      );
      return;
    }
    final vehicleId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: ZColors.surface,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            ZSpacing.lg,
            0,
            ZSpacing.lg,
            ZSpacing.lg,
          ),
          children: [
            Text(
              'Assign a vehicle to ${widget.driver.name}',
              style: ZTypography.titleMd,
            ),
            const SizedBox(height: ZSpacing.sm),
            for (final vehicle in vehicles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ZPlateBadge(plate: vehicle.registrationNumber),
                title: Text(
                  '${vehicle.categoryName} · ${vehicle.displayName}',
                  style: ZTypography.bodyStrong,
                ),
                subtitle: Text(
                  vehicle.isActive ? 'Active' : 'Paused',
                  style: ZTypography.caption
                      .copyWith(color: ZColors.textSecondary),
                ),
                onTap: () => Navigator.of(sheet).pop(vehicle.id),
              ),
          ],
        ),
      ),
    );
    if (vehicleId == null || !mounted) return;
    try {
      await ref.read(partnerApiProvider).assignVehicle(
            vehicleId: vehicleId,
            driverId: widget.driver.id,
          );
      ref.invalidate(fleetDriversProvider);
      ref.invalidate(fleetOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Vehicle assigned to ${widget.driver.name}.'),
          ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
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
              CircleAvatar(
                radius: 20,
                backgroundColor: ZColors.primaryTint,
                child: Text(
                  driver.name.characters.first.toUpperCase(),
                  style: ZTypography.bodyStrong.copyWith(color: ZColors.primary),
                ),
              ),
              const SizedBox(width: ZSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name, style: ZTypography.bodyStrong),
                    Text(
                      '${driver.phoneMasked} · ★ ${driver.ratingAvg.toStringAsFixed(1)}',
                      style: ZTypography.caption
                          .copyWith(color: ZColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ZStatusBadge(
                label: driver.online ? 'ONLINE' : 'OFFLINE',
                tone: driver.online
                    ? ZBadgeTone.success
                    : ZBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${driver.tripsToday} trips today · '
                  '${ZFormat.inr(driver.earningsTodayPaise)}',
                  style: ZTypography.caption
                      .copyWith(color: ZColors.textSecondary),
                ),
              ),
              if (driver.vehicleRegistration != null)
                ZPlateBadge(
                  plate: driver.vehicleRegistration!,
                  fontSize: 13,
                )
              else
                Text(
                  'No vehicle',
                  style:
                      ZTypography.caption.copyWith(color: ZColors.textTertiary),
                ),
              const SizedBox(width: ZSpacing.xs),
              ZIconButton(
                icon: Icons.link_rounded,
                tooltip: 'Assign vehicle',
                onPressed: _assign,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _FleetStatsSkeleton extends StatelessWidget {
  const _FleetStatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ZSkeleton(height: 112, radius: ZRadii.md)),
        SizedBox(width: ZSpacing.sm),
        Expanded(child: ZSkeleton(height: 112, radius: ZRadii.md)),
      ],
    );
  }
}

class _DriverSkeleton extends StatelessWidget {
  const _DriverSkeleton();

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
              ZSkeleton(width: 40, height: 40, radius: 20),
              SizedBox(width: ZSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ZSkeleton(width: 120, height: 14),
                  SizedBox(height: 6),
                  ZSkeleton(width: 160, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: ZSpacing.md),
          ZSkeleton(width: 220, height: 12),
        ],
      ),
    );
  }
}
