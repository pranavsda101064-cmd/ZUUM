import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Production map: MapLibre GL with OpenStreetMap vector tiles (OpenFreeMap
/// style, no API key). One widget for both mobile apps.
///
/// Widget tests and web (until the admin uses maplibre-gl-js) automatically
/// fall back to a deterministic canvas renderer so no platform view is needed.
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
    this.initialZoom = 13.5,
    this.tilt = 0,
    this.bearing = 0,
    this.showControls = false,
    this.styleUrl,
    this.recenterSignal = 0,
  });

  final ZMapCenter center;
  final List<ZMapMarker> markers;
  final ZMapRoute? route;

  /// 0..1 progressive polyline draw.
  final double routeProgress;

  final bool interactive;
  final VoidCallback? onTap;

  /// Camera follows this point (live driver tracking / navigation).
  final ZMapCenter? follow;

  final bool showAttribution;
  final double initialZoom;

  /// Navigation camera (MapLibre tilt/bearing), ignored by the canvas fallback.
  final double tilt;
  final double bearing;

  final bool showControls;
  final String? styleUrl;

  /// Increment to re-centre the native camera on [follow] or [center].
  final int recenterSignal;

  static const defaultStyleUrl = String.fromEnvironment(
    'MAP_STYLE_URL',
    defaultValue:
        'asset:packages/zuum_design_system/assets/map/positron_mono.json',
  );

  static List<ZMapCenter> progressPoints(List<ZMapCenter> points, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final n = points.length;
    if (n < 2) return points;
    final exact = clamped * (n - 1);
    final full = exact.floor();
    final result = <ZMapCenter>[];
    for (var i = 0; i <= full; i++) {
      result.add(points[i]);
    }
    if (full < n - 1) {
      final frac = exact - full;
      final a = points[full];
      final b = points[full + 1];
      result.add(
        ZMapCenter(
          a.lat + (b.lat - a.lat) * frac,
          a.lng + (b.lng - a.lng) * frac,
        ),
      );
    }
    return result.length >= 2 ? result : points;
  }

  static bool get _usesNativeEngine =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<ZMapView> createState() => _ZMapViewState();
}

class _ZMapViewState extends State<ZMapView> {
  MapLibreMapController? _controller;
  LineManager? _lines;
  CircleManager? _circles;
  bool _styleLoaded = false;
  bool _fittedRoute = false;
  int _lastProgressBucket = -1;
  String? _style;

  @override
  void initState() {
    super.initState();
    _resolveStyle();
  }

  Future<void> _resolveStyle() async {
    final requested = widget.styleUrl ?? ZMapView.defaultStyleUrl;
    if (!requested.startsWith('asset:')) {
      if (mounted) setState(() => _style = requested);
      return;
    }
    try {
      final json = await rootBundle.loadString(requested.substring(6));
      if (!mounted) return;
      setState(() => _style = json);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _style = 'https://tiles.openfreemap.org/styles/positron',
      );
    }
  }

  static String _hex(Color color) {
    final value = color.toARGB32();
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  double get _zoom => _controller?.cameraPosition?.zoom ?? widget.initialZoom;

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    _lines ??= LineManager(_controller!, enableInteraction: false);
    _circles ??= CircleManager(_controller!, enableInteraction: false);
    if (!(_lines!.isInitialized)) await _lines!.initialize();
    if (!(_circles!.isInitialized)) await _circles!.initialize();
    await _renderAnnotations();
    _fitRouteIfNeeded();
  }

  Future<void> _renderAnnotations() async {
    if (!_styleLoaded || _lines == null || _circles == null) return;
    await _lines!.clear();
    await _circles!.clear();

    final route = widget.route;
    if (route != null && route.points.length > 1) {
      final points = ZMapView.progressPoints(route.points, widget.routeProgress)
          .map((p) => LatLng(p.lat, p.lng))
          .toList();
      if (points.length >= 2) {
        final casing = route.color.computeLuminance() > 0.7
            ? ZColors.dark
            : ZColors.surface;
        await _lines!.add(
          Line(
            'route-casing',
            LineOptions(
              geometry: points,
              lineColor: _hex(casing),
              lineWidth: 9,
              lineOpacity: 0.95,
              lineJoin: 'round',
            ),
          ),
        );
        await _lines!.add(
          Line(
            'route-main',
            LineOptions(
              geometry: points,
              lineColor: _hex(route.color),
              lineWidth: 5.5,
              lineOpacity: 1,
              lineJoin: 'round',
            ),
          ),
        );
      }
    }

    final markers = widget.markers.isEmpty
        ? [ZMapMarker(widget.center.lat, widget.center.lng)]
        : widget.markers;
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      await _circles!.add(
        Circle(
          'marker-$i',
          CircleOptions(
            geometry: LatLng(marker.lat, marker.lng),
            circleRadius: marker.kind == ZMapMarkerKind.driver ? 9 : 7,
            circleColor: _hex(marker.color),
            circleStrokeColor: _hex(ZColors.surface),
            circleStrokeWidth: 2.5,
          ),
        ),
      );
    }
  }

  void _fitRouteIfNeeded() {
    final route = widget.route;
    if (_fittedRoute || route == null || route.points.length < 2) return;
    if (widget.follow != null) return;
    _fittedRoute = true;
    final lats = route.points.map((p) => p.lat);
    final lngs = route.points.map((p) => p.lng);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );
    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 48,
        top: 48,
        right: 48,
        bottom: 48,
      ),
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _followCamera() async {
    final follow = widget.follow;
    if (follow == null || _controller == null) return;
    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(follow.lat, follow.lng),
          zoom: _zoom,
          tilt: widget.tilt,
          bearing: widget.bearing,
        ),
      ),
      duration: const Duration(milliseconds: 450),
    );
  }

  void _recenter() {
    final target = widget.follow ?? widget.center;
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(target.lat, target.lng),
          zoom: widget.initialZoom,
          tilt: widget.tilt,
          bearing: widget.bearing,
        ),
      ),
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didUpdateWidget(ZMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!ZMapView._usesNativeEngine) return;

    if (widget.styleUrl != oldWidget.styleUrl) {
      _style = null;
      _resolveStyle();
    }

    if (widget.recenterSignal != oldWidget.recenterSignal) {
      _recenter();
    }

    final follow = widget.follow;
    if (follow != null &&
        (follow.lat != oldWidget.follow?.lat ||
            follow.lng != oldWidget.follow?.lng)) {
      _followCamera();
    }

    final progressBucket = (widget.routeProgress.clamp(0.0, 1.0) * 40).round();
    final routeChanged = widget.route != oldWidget.route;
    final markersChanged = !listEquals(widget.markers, oldWidget.markers);
    if (routeChanged ||
        markersChanged ||
        progressBucket != _lastProgressBucket) {
      _lastProgressBucket = progressBucket;
      _renderAnnotations();
      _fitRouteIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ZMapView._usesNativeEngine) {
      return _ZCanvasMap(
        center: widget.center,
        markers: widget.markers,
        route: widget.route,
        routeProgress: widget.routeProgress,
        showAttribution: widget.showAttribution,
        onTap: widget.onTap,
      );
    }

    if (_style == null) {
      return const ColoredBox(color: ZColors.background);
    }

    final target = widget.follow ?? widget.center;
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          styleString: _style!,
          initialCameraPosition: CameraPosition(
            target: LatLng(target.lat, target.lng),
            zoom: widget.initialZoom,
            tilt: widget.tilt,
            bearing: widget.bearing,
          ),
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: _onStyleLoaded,
          trackCameraPosition: true,
          rotateGesturesEnabled: widget.interactive,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
          dragEnabled: widget.interactive,
          compassEnabled: widget.interactive,
          attributionEnabled: false,
          logoEnabled: false,
          onMapClick: widget.onTap == null
              ? null
              : (_, _) => widget.onTap!(),
        ),
        if (widget.showAttribution) _AttributionPill(),
        if (widget.showControls)
          Positioned(
            right: ZSpacing.sm,
            bottom: ZSpacing.z64,
            child: _MapControls(
              onZoomIn: () => _controller
                  ?.animateCamera(CameraUpdate.zoomIn(), duration: ZMotion.fast),
              onZoomOut: () => _controller?.animateCamera(
                  CameraUpdate.zoomOut(),
                  duration: ZMotion.fast),
              onRecenter: _recenter,
            ),
          ),
      ],
    );
  }
}

class _AttributionPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ZColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            child: Text(
              '© OpenStreetMap contributors · OpenFreeMap',
              style: TextStyle(fontSize: 9, color: ZColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ControlButton(icon: Icons.add_rounded, onTap: onZoomIn, tooltip: 'Zoom in'),
        const SizedBox(height: ZSpacing.xs),
        _ControlButton(
            icon: Icons.remove_rounded, onTap: onZoomOut, tooltip: 'Zoom out'),
        const SizedBox(height: ZSpacing.xs),
        _ControlButton(
          icon: Icons.my_location_rounded,
          onTap: onRecenter,
          tooltip: 'Recenter',
          accent: true,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ZColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZRadii.sm),
          side: const BorderSide(color: ZColors.divider),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ZRadii.sm),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 19,
              color: ZColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Deterministic canvas renderer used in tests and on unsupported platforms.
class _ZCanvasMap extends StatelessWidget {
  const _ZCanvasMap({
    required this.center,
    required this.markers,
    required this.route,
    required this.routeProgress,
    required this.showAttribution,
    this.onTap,
  });

  final ZMapCenter center;
  final List<ZMapMarker> markers;
  final ZMapRoute? route;
  final double routeProgress;
  final bool showAttribution;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CanvasMapPainter(
              center: center,
              markers: markers,
              route: route,
              progress: routeProgress,
            ),
          ),
          if (showAttribution)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '© OpenStreetMap contributors · OpenFreeMap',
                  style: TextStyle(fontSize: 9, color: ZColors.textTertiary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CanvasMapPainter extends CustomPainter {
  _CanvasMapPainter({
    required this.center,
    required this.markers,
    required this.route,
    required this.progress,
  });

  final ZMapCenter center;
  final List<ZMapMarker> markers;
  final ZMapRoute? route;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF1F3F5);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = ZColors.divider.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final routePoints = route?.points ?? const <ZMapCenter>[];
    if (routePoints.length < 2) {
      final point = _project(center, center, size);
      _drawMarker(canvas, point, ZColors.primary, 8);
      return;
    }

    final minLat = routePoints.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    final maxLat = routePoints.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
    final minLng = routePoints.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    final maxLng = routePoints.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
    final bounds = ZMapCenter((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    Offset project(ZMapCenter p) {
      final latSpan = (maxLat - minLat).abs().clamp(0.002, 1.0);
      final lngSpan = (maxLng - minLng).abs().clamp(0.002, 1.0);
      final x = (p.lng - bounds.lng) / lngSpan * (size.width - 56) + size.width / 2;
      final y = -(p.lat - bounds.lat) / latSpan * (size.height - 56) + size.height / 2;
      return Offset(x, y);
    }

    final visible = ZMapView.progressPoints(routePoints, progress);
    final path = Path();
    final casing = Paint()
      ..color = ZColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Paint()
      ..color = route?.color ?? ZColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < visible.length; i++) {
      final offset = project(visible[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(path, casing);
    canvas.drawPath(path, line);

    for (final marker in markers) {
      _drawMarker(
        canvas,
        project(ZMapCenter(marker.lat, marker.lng)),
        marker.color,
        marker.kind == ZMapMarkerKind.driver ? 9 : 7,
      );
    }
  }

  Offset _project(ZMapCenter p, ZMapCenter origin, Size size) {
    return Offset(size.width / 2, size.height / 2);
  }

  void _drawMarker(Canvas canvas, Offset point, Color color, double radius) {
    canvas.drawCircle(
      point,
      radius + 2.5,
      Paint()..color = ZColors.surface,
    );
    canvas.drawCircle(point, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CanvasMapPainter old) {
    return old.center != center ||
        old.progress != progress ||
        old.route != route ||
        old.markers != markers;
  }
}

class ZMapCenter {
  const ZMapCenter(this.lat, this.lng);
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is ZMapCenter && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

enum ZMapMarkerKind { pickup, drop, driver, poi, vehicle }

class ZMapMarker {
  const ZMapMarker(
    this.lat,
    this.lng, {
    this.color = ZColors.primary,
    this.kind = ZMapMarkerKind.poi,
  });

  final double lat;
  final double lng;
  final Color color;
  final ZMapMarkerKind kind;

  @override
  bool operator ==(Object other) =>
      other is ZMapMarker &&
      other.lat == lat &&
      other.lng == lng &&
      other.color == color &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(lat, lng, color, kind);
}

class ZMapRoute {
  const ZMapRoute(this.points, {this.color = ZColors.primary});
  final List<ZMapCenter> points;
  final Color color;
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
