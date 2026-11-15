import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';

/// Home — Gemini spec §2d: full-bleed map, floating top bar (profile +
/// pickup pill), GPS recenter, and a draggable sheet with segmented
/// mode switcher, dark-bordered search trigger, quick vehicle strip,
/// and recent/saved places.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  static const _rideQuick = [
    ('Bike', 'veh_bike', '2m'),
    ('Auto', 'veh_auto', '3m'),
    ('Mini', 'veh_hatchback', '4m'),
    ('Sedan', 'veh_sedan', '5m'),
    ('SUV', 'veh_suv', '7m'),
  ];
  static const _goodsQuick = [
    ('2W Parcel', 'veh_2w_goods', '4m'),
    ('3W Cargo', 'veh_3w_goods', '5m'),
    ('Tata Ace', 'veh_ace', '6m'),
    ('Pickup', 'veh_pickup', '8m'),
    ('Tempo', 'veh_tempo', '10m'),
  ];

  void _openSearch() => context.push('/search');

  void _quickSelect(String code) {
    ref.read(bookingControllerProvider.notifier).selectCategory(code);
    _openSearch();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingControllerProvider);
    final goodsMode = draft.mode == BookingMode.goods;
    final pickupLabel = draft.pickup?.name ?? 'Current location';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ZMapView()),

          // Layer 2 — top floating bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpacing.lg,
                vertical: ZSpacing.md,
              ),
              child: Row(
                children: [
                  ZIconButton(
                    icon: Icons.person_outline_rounded,
                    filled: true,
                    onPressed: () => context.go('/account'),
                    tooltip: 'Account',
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  Expanded(
                    child: InkWell(
                      onTap: _openSearch,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: ZColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: ZColors.divider),
                          boxShadow: const [
                            BoxShadow(
                              color: ZColors.shadow,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: ZColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: ZSpacing.sm),
                            Expanded(
                              child: Text(
                                pickupLabel,
                                style: ZTypography.captionStrong,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: ZColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Layer 4 — draggable sheet.
          DraggableScrollableSheet(
            initialChildSize: 0.425,
            minChildSize: 0.3,
            maxChildSize: 0.75,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: ZColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: ZColors.divider)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: ZSpacing.sm),
                      decoration: BoxDecoration(
                        color: ZColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: ZSpacing.md),

                  // Segmented mode switcher.
                  ZSegmentedSwitch(
                    segments: const [
                      ZSegment(label: 'Ride', icon: Icons.local_taxi_outlined),
                      ZSegment(
                        label: 'Send Goods',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                    selectedIndex: goodsMode ? 1 : 0,
                    onChanged: (i) => ref
                        .read(bookingControllerProvider.notifier)
                        .setMode(i == 1 ? BookingMode.goods : BookingMode.ride),
                  ),
                  const SizedBox(height: ZSpacing.lg),

                  // Search trigger — high-affordance signboard border.
                  InkWell(
                    onTap: _openSearch,
                    borderRadius: BorderRadius.circular(ZRadii.md),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: ZColors.background,
                        borderRadius: BorderRadius.circular(ZRadii.md),
                        border: Border.all(color: ZColors.dark, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: ZColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: ZSpacing.md),
                          Expanded(
                            child: Text(
                              goodsMode
                                  ? 'Where is the parcel going?'
                                  : 'Where to?',
                              style: ZTypography.titleMd,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ZColors.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: ZColors.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Now',
                                  style: ZTypography.captionStrong,
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: ZColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ZSpacing.lg),

                  // Quick category strip (dev-labeled mock ETAs).
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: goodsMode
                          ? _goodsQuick.length
                          : _rideQuick.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: ZSpacing.sm),
                      itemBuilder: (_, i) {
                        final item = goodsMode ? _goodsQuick[i] : _rideQuick[i];
                        final codes = goodsMode
                            ? const [
                                'goods_2w',
                                'goods_3w',
                                'ace',
                                'pickup',
                                'tempo',
                              ]
                            : const [
                                'bike',
                                'auto',
                                'hatchback',
                                'sedan',
                                'suv',
                              ];
                        return ZQuickVehicleCard(
                          label: item.$1,
                          assetName: item.$2,
                          etaLabel: item.$3, // mock ETA (dev data)
                          selected:
                              draft.selectedCategoryCode == codes[i],
                          onTap: () => _quickSelect(codes[i]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: ZSpacing.lg),

                  ZImageCard(
                    photo:
                        goodsMode ? 'blr_goods_van' : 'blr_street_autos',
                    imageHeight: 110,
                    tag: goodsMode ? 'GOODS' : 'RIDE',
                    onTap: _openSearch,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goodsMode
                              ? 'Move a tiffin box or a 1BHK.'
                              : 'The city, on your terms.',
                          style: ZTypography.titleMd,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          goodsMode
                              ? '2W parcels, 3W cargo, Ace and Tempo with upfront fares.'
                              : 'Bikes, autos and cabs with honest, upfront fares.',
                          style: ZTypography.caption
                              .copyWith(color: ZColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZSpacing.lg),

                  // Recent / saved places (or first-time banner).
                  Text('Saved places', style: ZTypography.overline),
                  const SizedBox(height: ZSpacing.xs),
                  _SavedPlaces(onOpenSearch: _openSearch),
                  const SizedBox(height: ZSpacing.xl),
                ],
              ),
            ),
          ),

          // Layer 3 — GPS recenter (anchored above the sheet).
          Positioned(
            right: ZSpacing.lg,
            bottom: MediaQuery.sizeOf(context).height * 0.425 + ZSpacing.lg,
            child: ZIconButton(
              icon: Icons.my_location_rounded,
              filled: true,
              foreground: ZColors.primary,
              onPressed: () {}, // camera recenter hooks up with live GPS
              tooltip: 'Recenter map',
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPlaces extends ConsumerWidget {
  const _SavedPlaces({required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(_savedAddressesProvider);
    return addresses.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: ZSpacing.sm),
        child: ZSkeleton(width: double.infinity, height: 44, radius: 12),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          // First-time banner (spec §2d empty state).
          return InkWell(
            onTap: onOpenSearch,
            borderRadius: BorderRadius.circular(ZRadii.md),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
              decoration: BoxDecoration(
                color: ZColors.background,
                borderRadius: BorderRadius.circular(ZRadii.md),
                border: Border.all(color: ZColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_subway_outlined,
                      color: ZColors.primary),
                  const SizedBox(width: ZSpacing.md),
                  Expanded(
                    child: Text(
                      'Save Home & Work for 1-tap booking',
                      style: ZTypography.captionStrong,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: ZColors.textTertiary),
                ],
              ),
            ),
          );
        }
        final places = list.take(2).toList();
        return Column(
          children: [
            for (var i = 0; i < places.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ZListTile(
                title: places[i].name.isEmpty ? places[i].label : places[i].name,
                subtitle: places[i].address,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: ZColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    places[i].label == 'home'
                        ? Icons.home_outlined
                        : places[i].label == 'work'
                            ? Icons.work_outline_rounded
                            : Icons.bookmark_outline_rounded,
                    size: 16,
                    color: ZColors.primary,
                  ),
                ),
                onTap: onOpenSearch,
              ),
            ],
          ],
        );
      },
    );
  }
}

final _savedAddressesProvider = FutureProvider<List<SavedAddress>>((ref) {
  return ref.watch(apiContractProvider).savedAddresses();
});
