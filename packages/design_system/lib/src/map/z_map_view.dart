import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Real interactive map (OpenStreetMap tiles via flutter_map — no API key).
///
/// The only map entry point for all three apps. The Mapbox implementation can
/// replace this behind the same widget API when a token is configured; the
/// admin web dashboard reuses it as-is.
class ZMapView extends StatefulWidget {
  const ZMapView({
    super.key,
    this.center = const ZMapCenter(12.9716, 77.5946), // Bengaluru
    this.markers = const [],
    this.route,
    this.routeProgress = 1.0,
    this.interactive = true,
    this.onTap,
    this.follow,
    this.showAttribution = true,
  });

  final ZMapCenter center;
  final List<ZMapMarker> markers;
  final ZMapRoute? route;

  /// 0..1 progressive polyline draw (Gemini spec §4.4 route animation).
  final double routeProgress;

  final bool interactive;
  final VoidCallback? onTap;

  /// Camera follows this point (live driver tracking).
  final ZMapCenter? follow;

  final bool showAttribution;

  static List<LatLng> _progressPoints(List<ZMapCenter> points, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final n = points.length;
    final exact = clamped * (n - 1);
    final full = exact.floor();
    final result = <LatLng>[
      for (var i = 0; i <= full; i++) LatLng(points[i].lat, points[i].lng),
    ];
    if (full < n - 1) {
      final frac = exact - full;
      final a = points[full];
      final b = points[full + 1];
      result.add(LatLng(
        a.lat + (b.lat - a.lat) * frac,
        a.lng + (b.lng - a.lng) * frac,
      ));
    }
    return result.length >= 2
        ? result
        : [for (final p in points) LatLng(p.lat, p.lng)];
  }

  @override
  State<ZMapView> createState() => _ZMapViewState();
}

class _ZMapViewState extends State<ZMapView> {
  final _controller = MapController();
  var _fittedRoute = false;

  @override
  void didUpdateWidget(ZMapView old) {
    super.didUpdateWidget(old);
    final follow = widget.follow;
    if (follow != null &&
        (follow.lat != old.follow?.lat || follow.lng != old.follow?.lng)) {
      _controller.move(LatLng(follow.lat, follow.lng), _controller.camera.zoom);
      return;
    }
    final route = widget.route;
    if (!_fittedRoute && route != null && route.points.length > 1) {
      _fittedRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _controller.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints([
                for (final p in route.points) LatLng(p.lat, p.lng),
              ]),
              padding: const EdgeInsets.all(64),
            ),
          );
        } catch (_) {
          // Camera constraints can reject exotic coordinates — keep defaults.
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: LatLng(widget.center.lat, widget.center.lng),
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 19,
              backgroundColor: ZColors.skeleton,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
              onTap: widget.onTap == null
                  ? null
                  : (_, _) => widget.onTap!(),
            ),
            children: [
              TileLayer(
                // CartoDB Positron — light, desaturated, label-light tiles
                // that match the token palette without a Mapbox key.
                urlTemplate:
                    'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.zuum.customer',
                errorTileCallback: (_, _, _) {},
              ),
              if (route != null && route.points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: ZMapView._progressPoints(
                        route.points,
                        widget.routeProgress,
                      ),
                      strokeWidth: 5,
                      color: ZColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final m in widget.markers)
                    Marker(
                      point: LatLng(m.lat, m.lng),
                      width: 22,
                      height: 22,
                      child: _Pin(color: m.color),
                    ),
                  if (widget.markers.isEmpty)
                    Marker(
                      point: LatLng(widget.center.lat, widget.center.lng),
                      width: 22,
                      height: 22,
                      child: const _Pin(color: ZColors.primary),
                    ),
                ],
              ),
              if (widget.showAttribution)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ColoredBox(
                      color: ZColors.surface.withValues(alpha: 0.67),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(
                          '© OpenStreetMap contributors © CARTO',
                          style: TextStyle(fontSize: 9, color: ZColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ZMapCenter {
  const ZMapCenter(this.lat, this.lng);
  final double lat;
  final double lng;
}

class ZMapMarker {
  const ZMapMarker(this.lat, this.lng, {this.color = ZColors.primary});
  final double lat;
  final double lng;
  final Color color;
}

class ZMapRoute {
  const ZMapRoute(this.points);
  final List<ZMapCenter> points;
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: ZColors.shadowStrong, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

/// Small map legend chip (used on tracking screens).
class ZMapLegend extends StatelessWidget {
  const ZMapLegend({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: ZTypography.overline.copyWith(letterSpacing: 0.2)),
      ],
    );
  }
}
