import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
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

  Future<void> _directions(CampModel c) async {
    // Hands off to Google Maps for turn-by-turn — no in-app navigation needed.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the object passed through navigation; fall back to the loaded list
    // so a deep link or a back-stack restore still renders.
    final c = camp ?? ref.watch(campByIdProvider(campId));

    if (c == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
        body: Center(
          child: Text('Camp not found', style: AppTextStyles.body),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Camp Details', style: AppTextStyles.subtitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(c.name, style: AppTextStyles.title),
          if (c.organizerName != null) ...[
            const SizedBox(height: 4),
            Text(c.organizerName!, style: AppTextStyles.caption),
          ],
          if (c.startDate != null && c.endDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event, size: 15, color: AppColors.confirmedGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${c.startDate} → ${c.endDate}'
                    '${c.daysRemaining != null ? '  ·  ${c.daysRemaining} days left' : ''}',
                    style: AppTextStyles.caption.copyWith(
                      color: c.isEndingSoon ? AppColors.warningAmber : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (c.description != null && c.description!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(c.description!, style: AppTextStyles.body),
          ],

          if (c.servicesOffered.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Services offered', style: AppTextStyles.subtitle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.servicesOffered
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.confirmedGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s,
                        style: AppTextStyles.caption.copyWith(color: AppColors.confirmedGreen),
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
                  const ResQPKTileLayer(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(c.lat, c.lng),
                        width: MapSpec.touchTarget,
                        height: MapSpec.pinHeight,
                        alignment: Alignment.topCenter,
                        child: const MapDestinationPin(
                          color: AppColors.confirmedGreen,
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
            Text(c.address!, style: AppTextStyles.caption),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              if (c.contactPhone != null && c.contactPhone!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _call(context, c.contactPhone),
                    icon: const Icon(Icons.phone, size: 18, color: AppColors.confirmedGreen),
                    label: Text(
                      'Call Camp',
                      style: AppTextStyles.caption.copyWith(color: AppColors.confirmedGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: AppColors.confirmedGreen),
                    ),
                  ),
                ),
              if (c.contactPhone != null && c.contactPhone!.isNotEmpty)
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _directions(c),
                  icon: const Icon(Icons.navigation_outlined, size: 18, color: Colors.white),
                  label: Text('Directions', style: AppTextStyles.buttonLabel.copyWith(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.infoBlue,
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
              color: AppColors.surfaceTwo,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Medical camps offer free basic services. For emergencies always use SOS.',
                    style: AppTextStyles.caption,
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
