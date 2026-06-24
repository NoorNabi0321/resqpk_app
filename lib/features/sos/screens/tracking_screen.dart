import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../providers/sos_provider.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverPos;
  double _driverHeading = 0;
  int? _originalEtaSeconds;

  @override
  void initState() {
    super.initState();
    final c = ref.read(sosProvider).activeCase;
    if (c?.driverLat != null && c?.driverLng != null) {
      _driverPos = LatLng(c!.driverLat!, c.driverLng!);
      _driverHeading = c.driverHeading ?? 0;
    }
    _originalEtaSeconds = c?.estimatedDriverArrivalSeconds;
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _confirmCancel() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceTwo,
        title: Text('Cancel emergency?', style: AppTextStyles.subtitle),
        content: Text(
          'The ambulance will be released. Only cancel if you no longer need help.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Keep', style: AppTextStyles.caption),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(sosProvider.notifier).cancelActiveCase();
              if (mounted) context.go(Routes.home);
            },
            child: Text('Cancel SOS', style: AppTextStyles.caption.copyWith(color: AppColors.sosRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Live driver position from the case room broadcasts.
    ref.listen(driverLocationStreamProvider, (_, next) {
      next.whenData((data) {
        final lat = double.tryParse('${data['lat']}');
        final lng = double.tryParse('${data['lng']}');
        if (lat == null || lng == null || !mounted) return;
        setState(() {
          _driverPos = LatLng(lat, lng);
          _driverHeading = double.tryParse('${data['heading']}') ?? _driverHeading;
        });
        _mapController.move(_driverPos!, _mapController.camera.zoom);
      });
    });

    // Navigate home when the case completes or is cancelled.
    ref.listen(sosProvider.select((s) => s.status), (_, status) {
      if (status == SOSStatus.completed) {
        showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: AppColors.surfaceTwo,
            title: Text('You have arrived', style: AppTextStyles.subtitle),
            content: Text('You reached the hospital. Stay safe!',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(d).pop();
                  if (mounted) context.go(Routes.home);
                },
                child: Text('Done', style: AppTextStyles.caption.copyWith(color: AppColors.confirmedGreen)),
              ),
            ],
          ),
        );
      } else if (status == SOSStatus.cancelled || status == SOSStatus.idle) {
        if (mounted) context.go(Routes.home);
      }
    });

    final c = ref.watch(sosProvider).activeCase;
    if (c == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.sosRed)),
      );
    }

    final patient = LatLng(c.patientLat, c.patientLng);
    final driver = _driverPos ??
        (c.driverLat != null && c.driverLng != null ? LatLng(c.driverLat!, c.driverLng!) : null);
    final hospital = (c.hospitalLat != null && c.hospitalLng != null)
        ? LatLng(c.hospitalLat!, c.hospitalLng!)
        : null;

    final eta = c.estimatedDriverArrivalSeconds;
    _originalEtaSeconds ??= eta;
    final progress = (_originalEtaSeconds != null && _originalEtaSeconds! > 0 && eta != null)
        ? (1 - eta / _originalEtaSeconds!).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: driver ?? patient, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: AppConstants.mapTileUrl,
                userAgentPackageName: 'com.resqpk.resqpk_app',
              ),
              PolylineLayer(
                polylines: [
                  if (driver != null)
                    Polyline(points: [driver, patient], color: AppColors.infoBlue, strokeWidth: 4),
                  if (hospital != null)
                    Polyline(
                      points: [patient, hospital],
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      strokeWidth: 3,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: patient,
                    width: 24,
                    height: 24,
                    child: const _Dot(color: AppColors.sosRed),
                  ),
                  if (hospital != null)
                    Marker(
                      point: hospital,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.local_hospital, color: AppColors.confirmedGreen, size: 30),
                    ),
                  if (driver != null)
                    Marker(
                      point: driver,
                      width: 44,
                      height: 44,
                      child: Transform.rotate(
                        angle: _driverHeading * math.pi / 180,
                        child: const _AmbulancePin(),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _StatusPill(status: ref.watch(sosProvider).status),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _StatusCard(
              driverName: c.driverName ?? 'Driver',
              vehicleNumber: c.vehicleNumber ?? '',
              etaText: _etaText(eta, ref.watch(sosProvider).status),
              progress: progress,
              hospitalName: c.hospitalName ?? 'Hospital',
              onCallDriver: () => _call(c.driverPhone),
              onAiReport: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI report arrives in Module 6')),
              ),
              onCancel: _confirmCancel,
            ),
          ),
        ],
      ),
    );
  }

  String _etaText(int? seconds, SOSStatus status) {
    if (status == SOSStatus.arrived) return 'Arrived';
    if (seconds == null) return 'Calculating...';
    final mins = (seconds / 60).ceil();
    return 'ETA: $mins min';
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: AppColors.sosGlow, blurRadius: 12)],
      ),
    );
  }
}

class _AmbulancePin extends StatelessWidget {
  const _AmbulancePin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.infoBlue, shape: BoxShape.circle),
      padding: const EdgeInsets.all(8),
      child: const Icon(Icons.airport_shuttle, color: Colors.white, size: 22),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final SOSStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceTwo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emergency, color: AppColors.sosRed, size: 16),
          const SizedBox(width: 8),
          Text('EMERGENCY ACTIVE', style: AppTextStyles.caption.copyWith(color: AppColors.sosRed)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String driverName;
  final String vehicleNumber;
  final String etaText;
  final double progress;
  final String hospitalName;
  final VoidCallback onCallDriver;
  final VoidCallback onAiReport;
  final VoidCallback onCancel;

  const _StatusCard({
    required this.driverName,
    required this.vehicleNumber,
    required this.etaText,
    required this.progress,
    required this.hospitalName,
    required this.onCallDriver,
    required this.onAiReport,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceOne.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.infoBlue,
                    child: Text(
                      driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                      style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driverName, style: AppTextStyles.subtitle),
                        Text(vehicleNumber, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onCallDriver,
                    icon: const Icon(Icons.phone, color: AppColors.confirmedGreen),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(etaText, style: AppTextStyles.subtitle.copyWith(color: AppColors.confirmedGreen)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceThree,
                  color: AppColors.confirmedGreen,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.local_hospital, color: AppColors.confirmedGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(hospitalName, style: AppTextStyles.body)),
                  Text('Emergency ward ✓', style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAiReport,
                icon: const Icon(Icons.smart_toy_outlined, color: AppColors.infoBlue, size: 18),
                label: Text('Generate AI Report',
                    style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.infoBlue)),
              ),
              TextButton(
                onPressed: onCancel,
                child: Text('Cancel Emergency',
                    style: AppTextStyles.caption.copyWith(color: AppColors.sosRed)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
