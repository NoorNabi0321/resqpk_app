import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 exports its own geodesic Path, which would shadow dart:ui's Path
// used by the pin painter below.
import 'package:latlong2/latlong.dart' hide Path;

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// Shared map building blocks sized to Google Maps' published UI measurements,
/// so every ResQPK map reads the same way.
///
/// Sizes are in logical pixels, which is Flutter's equivalent of Android dp.
class MapSpec {
  MapSpec._();

  // --- Tiles ---------------------------------------------------------------
  // 512px @2x tiles drawn one zoom level "out" render labels ~2x larger than
  // the 256px default, which is what makes street names legible on a phone.
  static const double tileSize = 512;
  static const double zoomOffset = -1;

  // --- Markers (Google spec) ----------------------------------------------
  static const double userDot = 20; // blue puck: 20dp
  static const double userDotBorder = 2; // 2px white border
  static const double navigationPuck = 36; // heading chevron: 36dp
  static const double poiBadge = 24; // category circle: 24dp
  static const double poiGlyph = 16; // inner icon: 16dp
  static const double poiBadgeSelected = 40; // grows to 36-40dp when active
  static const double touchTarget = 48; // minimum accessible hit area
  static const double pinWidth = 27; // classic map pin: 27x43
  static const double pinHeight = 43;

  // --- Route lines ---------------------------------------------------------
  static const double routeWidth = 7; // active navigation: 6-8dp
  static const double routeCasing = 2; // 1-2dp outline for contrast
  static const double routeAlternateWidth = 5; // alternates: 4-6dp

  // --- Default camera ------------------------------------------------------
  // One level lower than before because zoomOffset renders larger content.
  static const double cityZoom = 14.5;
  static const double navigationZoom = 15.5;
}

/// The tile layer every ResQPK map should use.
class ResQPKTileLayer extends StatelessWidget {
  /// Light basemap for the light-themed screens; dark elsewhere.
  final bool light;

  const ResQPKTileLayer({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    // Very low-density screens gain nothing from @2x and would just pay the
    // bandwidth, so fall back to standard tiles there.
    final isHighDensity = MediaQuery.maybeDevicePixelRatioOf(context) != null &&
        MediaQuery.devicePixelRatioOf(context) > 1.5;

    final String url;
    if (light) {
      url = isHighDensity
          ? AppConstants.mapTileUrlLight
          : AppConstants.mapTileUrlLightStandard;
    } else {
      url = isHighDensity ? AppConstants.mapTileUrl : AppConstants.mapTileUrlStandard;
    }

    return TileLayer(
      urlTemplate: url,
      userAgentPackageName: 'com.resqpk.resqpk_app',
      tileSize: MapSpec.tileSize,
      zoomOffset: MapSpec.zoomOffset,
      maxNativeZoom: 20,
      panBuffer: 1,
    );
  }
}

/// Route polyline with a contrasting casing, the way navigation apps draw it.
/// flutter_map renders the border beneath the stroke, giving the 1-2dp outline
/// that keeps the line visible over both dark and light terrain.
List<Polyline> routePolyline(
  List<LatLng> points, {
  required Color color,
  bool isAlternate = false,
}) {
  if (points.length < 2) return const [];
  return [
    Polyline(
      points: points,
      color: color,
      strokeWidth: isAlternate ? MapSpec.routeAlternateWidth : MapSpec.routeWidth,
      borderColor: Colors.white.withValues(alpha: 0.85),
      borderStrokeWidth: MapSpec.routeCasing,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
    ),
  ];
}

/// The user's own position — Google's "blue puck": a 20dp dot with a 2px white
/// border, optionally inside a translucent GPS-accuracy halo.
class UserLocationDot extends StatelessWidget {
  final Color color;
  final bool showPulse;

  const UserLocationDot({
    super.key,
    this.color = AppColors.infoBlue,
    this.showPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return _PulseHalo(
      color: color,
      enabled: showPulse,
      child: Container(
        width: MapSpec.userDot,
        height: MapSpec.userDot,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: MapSpec.userDotBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Vehicle marker with a heading chevron — Google's 36dp navigation puck.
class NavigationPuck extends StatelessWidget {
  final double headingDegrees;
  final Color color;
  final IconData icon;

  const NavigationPuck({
    super.key,
    this.headingDegrees = 0,
    this.color = AppColors.infoBlue,
    this.icon = Icons.navigation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MapSpec.navigationPuck,
      height: MapSpec.navigationPuck,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6),
          ],
        ),
        child: Transform.rotate(
          angle: headingDegrees * math.pi / 180,
          child: Icon(icon, color: Colors.white, size: MapSpec.poiGlyph + 2),
        ),
      ),
    );
  }
}

/// Category badge — a 24dp circle around a 16dp glyph, as Google draws POIs.
class MapPoiBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;

  const MapPoiBadge({
    super.key,
    required this.icon,
    required this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? MapSpec.poiBadgeSelected : MapSpec.poiBadge;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 5),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: selected ? MapSpec.poiGlyph + 6 : MapSpec.poiGlyph,
      ),
    );
  }
}

/// Destination marker in the classic 27x43 pin shape.
class MapDestinationPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const MapDestinationPin({
    super.key,
    required this.color,
    this.icon = Icons.local_hospital,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MapSpec.pinWidth,
      height: MapSpec.pinHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MapSpec.pinWidth,
            height: MapSpec.pinWidth,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 5),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          // Tapered stem so the pin points at the exact coordinate.
          CustomPaint(
            size: const Size(10, MapSpec.pinHeight - MapSpec.pinWidth),
            painter: _PinStemPainter(color: color),
          ),
        ],
      ),
    );
  }
}

class _PinStemPainter extends CustomPainter {
  final Color color;

  _PinStemPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinStemPainter oldDelegate) => oldDelegate.color != color;
}

/// Expanding halo used behind a live position, matching the GPS accuracy ring.
class _PulseHalo extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool enabled;

  const _PulseHalo({required this.child, required this.color, required this.enabled});

  @override
  State<_PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<_PulseHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return Center(child: widget.child);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: MapSpec.userDot * (1 + t * 1.8),
                height: MapSpec.userDot * (1 + t * 1.8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.28 * (1 - t)),
                  shape: BoxShape.circle,
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
