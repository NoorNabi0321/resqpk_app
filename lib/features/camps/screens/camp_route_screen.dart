import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/map/resqpk_map.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../data/camps_repository.dart';
import '../data/models/camp_model.dart';

/// The way to a medical camp, on the app's own map.
///
/// It used to hand off to Google Maps, which is a fine thing to offer and a
/// poor thing to force: someone on a cheap phone with no Maps installed, or no
/// room to install it, got a button that did nothing. The road line is drawn
/// here, with a handoff still available for turn-by-turn voice guidance.
class CampRouteScreen extends ConsumerStatefulWidget {
  const CampRouteScreen({super.key, required this.camp});

  final CampModel camp;

  @override
  ConsumerState<CampRouteScreen> createState() => _CampRouteScreenState();
}

class _CampRouteScreenState extends ConsumerState<CampRouteScreen> {
  final MapController _map = MapController();
  final CampsRepository _repo = CampsRepository();

  List<LatLng> _route = const [];
  LatLng? _me;
  bool _loading = true;
  String? _error;

  LatLng get _camp => LatLng(widget.camp.lat, widget.camp.lng);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final service = ref.read(locationServiceProvider);
      final position = service.lastPosition
          ?? await service.getCurrentPosition()
              .timeout(const Duration(seconds: 12), onTimeout: () => null);
      if (position == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Turn on location to see the way from where you are.';
          });
        }
        return;
      }

      final me = LatLng(position.latitude, position.longitude);
      final coords = await _repo.getRouteToCamp(widget.camp.id, me.latitude, me.longitude);

      if (!mounted) return;
      setState(() {
        _me = me;
        _route = [for (final c in coords) LatLng(c.lat, c.lng)];
        _loading = false;
      });
      _fitBounds();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not work out the way there.';
        });
      }
    }
  }

  /// Frame both ends of the journey, with room for the card over the bottom.
  void _fitBounds() {
    final me = _me;
    if (me == null) return;
    final points = _route.isNotEmpty ? _route : [me, _camp];
    try {
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 220),
          maxZoom: 16,
        ),
      );
    } catch (_) {
      // A degenerate box — standing at the camp — is not worth failing over.
    }
  }

  /// Turn-by-turn with a voice belongs to a real navigation app; this offers
  /// it rather than insisting on it.
  Future<void> _openExternal() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_camp.latitude},${_camp.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maps app is installed to hand over to.')),
      );
    }
  }

  String get _distanceText {
    final me = _me;
    if (me == null) return '';
    // Along the road when there is a road line, straight line otherwise.
    var metres = 0.0;
    if (_route.length >= 2) {
      const d = Distance();
      for (var i = 1; i < _route.length; i++) {
        metres += d.as(LengthUnit.Meter, _route[i - 1], _route[i]);
      }
    } else {
      metres = const Distance().as(LengthUnit.Meter, me, _camp);
    }
    return metres < 1000
        ? '${metres.round()} m away'
        : '${(metres / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _camp, initialZoom: 14),
            children: [
              const ResQPKTileLayer(light: true),
              PolylineLayer(
                polylines: [
                  if (_route.length >= 2)
                    ...routePolyline(_route, color: Resq.brand)
                  else if (_me != null)
                    // Straight line while the road route is unavailable. It
                    // still points the right way, which beats an empty map.
                    ...routePolyline([_me!, _camp], color: Resq.brand, isAlternate: true),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _camp,
                    width: MapSpec.touchTarget,
                    height: MapSpec.pinHeight,
                    alignment: Alignment.topCenter,
                    child: const MapDestinationPin(color: Resq.ready),
                  ),
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: MapSpec.touchTarget,
                      height: MapSpec.touchTarget,
                      child: const UserLocationDot(color: Resq.info),
                    ),
                ],
              ),
            ],
          ),

          // Back, over the map.
          Positioned(
            left: Resq.space4,
            top: MediaQuery.paddingOf(context).top + Resq.space2,
            child: Material(
              color: Resq.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: () => context.pop(),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: Resq.tapTarget,
                  height: Resq.tapTarget,
                  child: Icon(Icons.arrow_back_rounded, color: Resq.ink),
                ),
              ),
            ),
          ),

          if (_loading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + Resq.space2,
              left: 0,
              right: 0,
              child: const Center(child: _FindingChip()),
            ),

          Positioned(
            left: Resq.space4,
            right: Resq.space4,
            bottom: Resq.space4 + MediaQuery.paddingOf(context).bottom,
            child: _RouteCard(
              camp: widget.camp,
              distanceText: _distanceText,
              error: _error,
              onRecentre: _fitBounds,
              onOpenExternal: _openExternal,
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingChip extends StatelessWidget {
  const _FindingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Resq.space4, vertical: Resq.space2),
      decoration: BoxDecoration(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusPill),
        boxShadow: Resq.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Resq.brand),
          ),
          const SizedBox(width: Resq.space2),
          Text('Working out the way', style: ResqType.caption(color: Resq.inkSoft)),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.camp,
    required this.distanceText,
    required this.error,
    required this.onRecentre,
    required this.onOpenExternal,
  });

  final CampModel camp;
  final String distanceText;
  final String? error;
  final VoidCallback onRecentre;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Resq.space4),
      decoration: BoxDecoration(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        border: Border.all(color: Resq.border),
        boxShadow: Resq.raisedShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(camp.name, style: ResqType.section(), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (distanceText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(distanceText, style: ResqType.caption(color: Resq.brandInk)),
          ],
          if (camp.address != null) ...[
            const SizedBox(height: Resq.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, size: 14, color: Resq.inkSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    camp.address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ResqType.caption(),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: Resq.space3),
            Text(error!, style: ResqType.caption(color: Resq.decision)),
          ],
          const SizedBox(height: Resq.space4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRecentre,
                  icon: const Icon(Icons.my_location_rounded, size: 18, color: Resq.inkSoft),
                  label: Text('Recentre', style: ResqType.button(color: Resq.inkSoft)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(Resq.tapTarget),
                    side: const BorderSide(color: Resq.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Resq.space3),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenExternal,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text('Navigate', style: ResqType.button()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Resq.brandInk,
                    minimumSize: const Size.fromHeight(Resq.tapTarget),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
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
