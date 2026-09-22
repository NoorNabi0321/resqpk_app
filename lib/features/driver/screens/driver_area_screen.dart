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
import '../../../core/widgets/map_card.dart';
import '../../camps/providers/camps_provider.dart';
import '../../home/providers/home_providers.dart';
import '../widgets/driver_chrome.dart';

/// The ground a driver is working on: which hospitals take emergencies, and
/// where the camps are.
///
/// Dispatch picks the destination during a case, but between cases a driver
/// still has to know their area — which emergency ward is ten minutes away at
/// this hour, and which gate to use. This is that map, with the phone numbers
/// attached so a driver can ring ahead rather than arrive and find out.
class DriverAreaScreen extends ConsumerStatefulWidget {
  const DriverAreaScreen({super.key});

  @override
  ConsumerState<DriverAreaScreen> createState() => _DriverAreaScreenState();
}

class _DriverAreaScreenState extends ConsumerState<DriverAreaScreen> {
  final MapController _controller = MapController();

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(currentPositionStreamProvider).asData?.value ??
        ref.read(locationServiceProvider).lastPosition;
    final me = position == null
        ? const LatLng(25.3792, 68.3683)
        : LatLng(position.latitude, position.longitude);

    final hospitals = ref.watch(nearbyHospitalsProvider);
    final camps = ref.watch(nearbyCampsProvider).asData?.value ?? const [];
    final hospitalList = hospitals.asData?.value ?? const [];

    return DriverScaffold(
      title: 'My area',
      subtitle: 'Emergency wards and camps around you',
      onBack: () => context.pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MapCard(
            height: 260,
            overlay: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(Resq.space3),
                child: MapControlButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Centre on me',
                  onTap: () => _controller.move(me, MapSpec.navigationZoom),
                ),
              ),
            ),
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(initialCenter: me, initialZoom: MapSpec.cityZoom),
              children: [
                // Light tiles, like every other map in the app.
                const ResQPKTileLayer(light: true),
                MarkerLayer(
                  markers: [
                    for (final h in hospitalList)
                      if (h['lat'] != null && h['lng'] != null)
                        Marker(
                          point: LatLng(
                            double.tryParse('${h['lat']}') ?? 0,
                            double.tryParse('${h['lng']}') ?? 0,
                          ),
                          width: MapSpec.touchTarget,
                          height: MapSpec.pinHeight,
                          alignment: Alignment.topCenter,
                          child: const MapDestinationPin(
                            color: Resq.critical,
                            icon: Icons.local_hospital,
                          ),
                        ),
                    for (final c in camps)
                      Marker(
                        point: LatLng(c.lat, c.lng),
                        width: MapSpec.touchTarget,
                        height: MapSpec.pinHeight,
                        alignment: Alignment.topCenter,
                        child: const MapDestinationPin(
                          color: Resq.ready,
                          icon: Icons.medical_services,
                        ),
                      ),
                    Marker(
                      point: me,
                      width: MapSpec.touchTarget,
                      height: MapSpec.touchTarget,
                      child: const NavigationPuck(color: Resq.info, icon: Icons.navigation),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Resq.space3),
          Row(
            children: [
              _LegendDot(color: Resq.critical, label: 'Emergency ward'),
              const SizedBox(width: Resq.space4),
              _LegendDot(color: Resq.ready, label: 'Medical camp'),
              const SizedBox(width: Resq.space4),
              _LegendDot(color: Resq.info, label: 'You'),
            ],
          ),
          const SizedBox(height: Resq.space4),
          Expanded(
            child: hospitals.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Resq.ready)),
              error: (_, __) => Center(
                child: Text(
                  'Could not load hospitals. Pull down on the duty screen to retry.',
                  textAlign: TextAlign.center,
                  style: ResqType.body(color: Resq.inkMuted),
                ),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text(
                        'No emergency hospital found near this position.',
                        style: ResqType.body(color: Resq.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: Resq.space6),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Resq.space3),
                      itemBuilder: (_, i) {
                        final h = list[i];
                        return _HospitalRow(hospital: h, onCall: () => _call(
                              h['emergency_phone']?.toString(),
                            ));
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HospitalRow extends StatelessWidget {
  const _HospitalRow({required this.hospital, required this.onCall});

  final Map<String, dynamic> hospital;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final beds = hospital['available_beds'];
    final open = hospital['has_emergency_ward'] == true;

    return DriverCard(
      padding: const EdgeInsets.all(Resq.space3),
      accent: open ? Resq.ready : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospital['name']?.toString() ?? 'Hospital',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ResqType.bodyStrong(color: Resq.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (hospital['distanceText'] != null) '${hospital['distanceText']} away',
                    if (open) 'Emergency ward',
                    if (beds != null) '$beds beds free',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ResqType.caption(color: Resq.inkMuted),
                ),
              ],
            ),
          ),
          if ((hospital['emergency_phone']?.toString() ?? '').isNotEmpty)
            IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded, color: Resq.ready),
              constraints: const BoxConstraints(
                minWidth: Resq.tapTarget,
                minHeight: Resq.tapTarget,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

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
        const SizedBox(width: 6),
        Text(label, style: ResqType.micro(color: Resq.inkMuted)),
      ],
    );
  }
}
