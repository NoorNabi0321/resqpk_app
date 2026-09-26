import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/map/resqpk_map.dart';
import '../data/models/camp_model.dart';
import '../providers/camps_provider.dart';

class CampDetailScreen extends ConsumerWidget {
  final String campId;
  final CampModel? camp;

  const CampDetailScreen({super.key, required this.campId, this.camp});

  Future<void> _call(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Opens the way there on the app's own map.
  ///
  /// This used to hand straight off to Google Maps, which is fine to offer and
  /// poor to force: on a phone without it the button did nothing at all, with
  /// no way to tell. The route screen draws the road line here and still
  /// offers the handoff for turn-by-turn voice guidance.
  void _directions(BuildContext context, CampModel c) {
    context.push('${Routes.camps}/${c.id}/route', extra: c);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the object passed through navigation; fall back to the loaded list
    // so a deep link or a back-stack restore still renders.
    final c = camp ?? ref.watch(campByIdProvider(campId));

    if (c == null) {
      return Scaffold(
        backgroundColor: Resq.canvas,
        appBar: AppBar(backgroundColor: Resq.canvas, elevation: 0),
        body: Center(
          child: Text('Camp not found', style: ResqType.body()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Resq.canvas,
      appBar: AppBar(
        backgroundColor: Resq.canvas,
        elevation: 0,
        title: Text('Camp Details', style: ResqType.section()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(c.name, style: ResqType.title()),
          if (c.organizerName != null) ...[
            const SizedBox(height: 4),
            Text(c.organizerName!, style: ResqType.caption()),
          ],
          if (c.startDate != null && c.endDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event, size: 15, color: Resq.ready),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${c.startDate} → ${c.endDate}'
                    '${c.daysRemaining != null ? '  ·  ${c.daysRemaining} days left' : ''}',
                    style: ResqType.caption().copyWith(
                      color: c.isEndingSoon ? Resq.decision : Resq.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (c.description != null && c.description!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(c.description!, style: ResqType.body()),
          ],

          if (c.servicesOffered.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Services offered', style: ResqType.section()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.servicesOffered
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Resq.ready.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s,
                        style: ResqType.caption().copyWith(color: Resq.ready),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(c.lat, c.lng),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  // Light, like every other map in the app. This was the one
                  // screen still on the dark basemap, which read as a
                  // different app on a cream page.
                  const ResQPKTileLayer(light: true),
                  MarkerLayer(
                    markers: [
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
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (c.address != null) ...[
            const SizedBox(height: 10),
            Text(c.address!, style: ResqType.caption()),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              if (c.contactPhone != null && c.contactPhone!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _call(context, c.contactPhone),
                    icon: const Icon(Icons.phone, size: 18, color: Resq.ready),
                    label: Text(
                      'Call Camp',
                      style: ResqType.caption().copyWith(color: Resq.ready),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Resq.ready),
                    ),
                  ),
                ),
              if (c.contactPhone != null && c.contactPhone!.isNotEmpty)
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _directions(context, c),
                  icon: const Icon(Icons.navigation_outlined, size: 18, color: Colors.white),
                  label: Text('Directions', style: ResqType.button().copyWith(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    // brandInk, not brand: white on brand is 3.4:1, which
                    // fails at this label size. Same pair as PrimaryButton.
                    backgroundColor: Resq.brandInk,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Resq.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Resq.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Medical camps offer free basic services. For emergencies always use SOS.',
                    style: ResqType.caption(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
