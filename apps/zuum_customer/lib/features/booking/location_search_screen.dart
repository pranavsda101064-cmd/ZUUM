import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';

import '../../shared/current_place.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';

enum _Target { pickup, drop }

/// Location search — Gemini spec §2e: dual-timeline input card with swap,
/// quick chips (Pin on map / Home / Office), highlighted match substrings,
/// tabular distances, debounced shimmer results.
class LocationSearchScreen extends ConsumerStatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  ConsumerState<LocationSearchScreen> createState() =>
      _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();

  _Target _target = _Target.drop;
  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  bool _searching = false;
  String _query = '';

  /// Placeholder for the real device fix (Mapbox/OSM GPS) — mock coordinates.
  static const _fallbackLocation = PlaceSuggestion(
    name: 'Current location',
    address: 'Koramangala, Bengaluru',
    lat: 12.9352,
    lng: 77.6245,
  );

  PlaceSuggestion _currentLocation = _fallbackLocation;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingControllerProvider);
    _pickupController.text = draft.pickup?.name ?? '';
    _dropController.text = draft.drop?.name ?? '';
    _target = draft.pickup == null ? _Target.pickup : _Target.drop;
    _resolveGps();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_target == _Target.pickup) {
        _pickupFocus.requestFocus();
      } else {
        _dropFocus.requestFocus();
      }
      _runSearch('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(value));
  }

  Future<void> _resolveGps() async {
    final place = await currentPlace();
    if (!mounted || place == null) return;
    setState(() => _currentLocation = place);
  }

  Future<void> _useCurrentLocation() async {
    final place = await currentPlace();
    if (!mounted) return;
    if (place != null) setState(() => _currentLocation = place);
    _choose(_currentLocation);
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final service = ref.read(placeSearchProvider);
    final results = await service.search(
      query,
      proximityLat: _currentLocation.lat,
      proximityLng: _currentLocation.lng,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _swap() {
    final pickup = _pickupController.text;
    _pickupController.text = _dropController.text;
    _dropController.text = pickup;
    ref.read(bookingControllerProvider.notifier).setPickup(
          PlaceSuggestion(
            name: _pickupController.text.isEmpty
                ? _currentLocation.name
                : _pickupController.text,
            address: '',
            lat: _currentLocation.lat,
            lng: _currentLocation.lng,
          ),
        );
    setState(() => _target = _Target.pickup);
    _pickupFocus.requestFocus();
    _onQueryChanged(_pickupController.text);
  }

  void _choose(PlaceSuggestion place) {
    final controller = ref.read(bookingControllerProvider.notifier);
    if (_target == _Target.pickup) {
      controller.setPickup(place);
      setState(() {
        _pickupController.text = place.name;
        _target = _Target.drop;
        _dropController.clear();
        _query = '';
        _results = const [];
      });
      _runSearch('');
      _dropFocus.requestFocus();
    } else {
      controller.setDrop(place);
      setState(() => _dropController.text = place.name);
      final draft = ref.read(bookingControllerProvider);
      if (draft.hasRoute) {
        final destination =
            draft.mode == BookingMode.goods ? '/booking/goods' : '/booking/options';
        context.pushReplacement(destination);
      } else {
        setState(() => _target = _Target.pickup);
        _pickupFocus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingControllerProvider);
    final isGoods = draft.mode == BookingMode.goods;
    return Scaffold(
      backgroundColor: ZColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: back + title + mode badge.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpacing.sm,
                ZSpacing.sm,
                ZSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  ZIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: ZSpacing.xs),
                  Expanded(
                    child: Text(
                      isGoods ? 'Parcel route' : 'Plan your ride',
                      style: ZTypography.titleMd,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ZColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isGoods ? 'GOODS' : 'RIDE',
                      style: ZTypography.overline.copyWith(
                        color: ZColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpacing.sm),

            // Dual-timeline input card with swap.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(ZSpacing.md),
                decoration: BoxDecoration(
                  color: ZColors.background,
                  borderRadius: BorderRadius.circular(ZRadii.md),
                  border: Border.all(color: ZColors.divider),
                ),
                child: Row(
                  children: [
                    const _TimelineDots(),
                    const SizedBox(width: ZSpacing.md),
                    Expanded(
                      child: Column(
                        children: [
                          _FieldRow(
                            controller: _pickupController,
                            focusNode: _pickupFocus,
                            hint: 'Current Location (Koramangala)',
                            active: _target == _Target.pickup,
                            onTap: () => setState(() => _target = _Target.pickup),
                            onChanged: _onQueryChanged,
                          ),
                          const Divider(height: 20),
                          _FieldRow(
                            controller: _dropController,
                            focusNode: _dropFocus,
                            hint: 'Search street, metro station, or landmark',
                            active: _target == _Target.drop,
                            autofocus: true,
                            onTap: () => setState(() => _target = _Target.drop),
                            onChanged: _onQueryChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ZSpacing.xs),
                    InkWell(
                      onTap: _swap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: ZColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ZColors.divider),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: ZColors.dark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZSpacing.md),

            // Quick chips.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
              child: Row(
                children: [
                  ZChip(
                    label: 'Pin on map',
                    icon: Icons.pin_drop_outlined,
                    onTap: () => _notReady('Pin on map'),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  ZChip(
                    label: 'Home',
                    icon: Icons.home_outlined,
                    onTap: () => _chooseSaved('home'),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  ZChip(
                    label: 'Office',
                    icon: Icons.work_outline_rounded,
                    onTap: () => _chooseSaved('work'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpacing.md),
            const Divider(height: 1),

            Expanded(
              child: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(ZSpacing.lg),
                      child: ZSkeletonList(itemCount: 5),
                    )
                  : _query.trim().isEmpty || _results.isEmpty
                      ? _QuickList(
                          target: _target,
                          draft: draft,
                          onChoose: _choose,
                          onCurrentLocation: _useCurrentLocation,
                        )
                      : _SuggestionsList(
                          results: _results,
                          target: _target,
                          query: _query,
                          onChoose: _choose,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _notReady(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature lands with the Mapbox location flow.'),
        ),
      );
  }

  void _chooseSaved(String label) async {
    final saved = await ref.read(apiContractProvider).savedAddresses();
    final match = saved.where((a) => a.label == label).firstOrNull;
    if (match == null) {
      _notReady('Save a $label address first');
      return;
    }
    _choose(
      PlaceSuggestion(
        name: match.name.isEmpty ? match.label : match.name,
        address: match.address,
        lat: match.lat,
        lng: match.lng,
      ),
    );
  }
}

class _TimelineDots extends StatelessWidget {
  const _TimelineDots();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.circle, size: 10, color: ZColors.success),
        SizedBox(height: 6),
        SizedBox(
          width: 2,
          height: 36,
          child: CustomPaint(painter: _DashPainter()),
        ),
        SizedBox(height: 6),
        Icon(Icons.location_on_rounded, size: 16, color: ZColors.error),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ZColors.textTertiary
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 4),
        paint,
      );
      y += 7;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.active,
    required this.onTap,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool active;
  final bool autofocus;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onTap: onTap,
      style: ZTypography.bodyStrong.copyWith(
        color: active ? ZColors.textPrimary : ZColors.textSecondary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintStyle: ZTypography.body.copyWith(color: ZColors.textTertiary),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({
    required this.results,
    required this.target,
    required this.query,
    required this.onChoose,
  });

  final List<PlaceSuggestion> results;
  final _Target target;
  final String query;
  final ValueChanged<PlaceSuggestion> onChoose;

  /// Matched substring rendered in Primary (spec §2e).
  List<TextSpan> _highlighted(String name) {
    final q = query.trim();
    if (q.isEmpty) return [TextSpan(text: name)];
    final lower = name.toLowerCase();
    final idx = lower.indexOf(q.toLowerCase());
    if (idx < 0) return [TextSpan(text: name)];
    return [
      TextSpan(text: name.substring(0, idx)),
      TextSpan(
        text: name.substring(idx, idx + q.length),
        style: const TextStyle(color: ZColors.primary),
      ),
      TextSpan(text: name.substring(idx + q.length)),
    ];
  }

  static double _distanceKm(PlaceSuggestion p) {
    // Haversine against the mock current location (dev coordinates).
    const lat1 = 12.9352, lng1 = 77.6245;
    const r = 6371.0;
    final dLat = (p.lat - lat1) * math.pi / 180;
    final dLng = (p.lng - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(p.lat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
      itemBuilder: (_, i) {
        final place = results[i];
        return InkWell(
          onTap: () => onChoose(place),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ZSpacing.md),
            child: Row(
              children: [
                Icon(
                  target == _Target.pickup
                      ? Icons.my_location_rounded
                      : Icons.location_on_outlined,
                  color: ZColors.textTertiary,
                ),
                const SizedBox(width: ZSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: _highlighted(place.name),
                          style: ZTypography.bodyStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        place.address,
                        style: ZTypography.caption
                            .copyWith(color: ZColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZSpacing.sm),
                Text(
                  '${_distanceKm(place).toStringAsFixed(1)} km',
                  style: ZTypography.overline.copyWith(
                    color: ZColors.textTertiary,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickList extends ConsumerWidget {
  const _QuickList({
    required this.target,
    required this.draft,
    required this.onChoose,
    required this.onCurrentLocation,
  });

  final _Target target;
  final BookingDraft draft;
  final ValueChanged<PlaceSuggestion> onChoose;
  final VoidCallback onCurrentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(_savedAddressesProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
      children: [
        if (target == _Target.pickup)
          ZListTile(
            title: 'Current location',
            subtitle: 'Koramangala, Bengaluru',
            leading: const Icon(Icons.my_location_rounded,
                color: ZColors.primary),
            onTap: onCurrentLocation,
          ),
        saved.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(ZSpacing.lg),
            child: ZSkeleton(width: double.infinity, height: 44, radius: 12),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (addresses) => Column(
            children: [
              for (final a in addresses)
                ZListTile(
                  title: a.name.isEmpty ? a.label : a.name,
                  subtitle: a.address,
                  leading: Icon(
                    a.label == 'home'
                        ? Icons.home_outlined
                        : a.label == 'work'
                            ? Icons.work_outline_rounded
                            : Icons.bookmark_outline_rounded,
                    color: ZColors.textTertiary,
                  ),
                  onTap: () => onChoose(
                    PlaceSuggestion(
                      name: a.name.isEmpty ? a.label : a.name,
                      address: a.address,
                      lat: a.lat,
                      lng: a.lng,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, ZSpacing.lg, 0, ZSpacing.sm),
          child: Text('Popular in Bengaluru', style: ZTypography.overline),
        ),
        const _PopularPlaces(),
      ],
    );
  }
}

final _savedAddressesProvider = FutureProvider<List<SavedAddress>>(
  (ref) => ref.watch(apiContractProvider).savedAddresses(),
);

class _PopularPlaces extends ConsumerStatefulWidget {
  const _PopularPlaces();

  @override
  ConsumerState<_PopularPlaces> createState() => _PopularPlacesState();
}

class _PopularPlacesState extends ConsumerState<_PopularPlaces> {
  List<PlaceSuggestion> _places = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final places = await ref.read(placeSearchProvider).search(
            '',
            proximityLat: 12.9352,
            proximityLng: 77.6245,
            limit: 6,
          );
      if (mounted) setState(() => _places = places);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final place in _places)
          ZListTile(
            title: place.name,
            subtitle: place.address,
            leading: const Icon(Icons.place_outlined,
                color: ZColors.textTertiary),
            onTap: () => _choose(place),
          ),
      ],
    );
  }

  void _choose(PlaceSuggestion place) {
    final controller = ref.read(bookingControllerProvider.notifier);
    controller.setDrop(place);
    final draft = ref.read(bookingControllerProvider);
    if (draft.hasRoute) {
      final destination = draft.mode == BookingMode.goods
          ? '/booking/goods'
          : '/booking/options';
      context.pushReplacement(destination);
    }
  }
}
