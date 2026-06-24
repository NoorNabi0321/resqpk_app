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
import '../../../core/location/location_provider.dart';
import '../../../core/router/app_router.dart';
import '../../sos/data/models/emergency_case_model.dart';
import '../../sos/data/sos_repository.dart';
import '../providers/driver_realtime_provider.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final String caseId;

  const DriverNavigationScreen({super.key, required this.caseId});

  @override
  ConsumerState<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends ConsumerState<DriverNavigationScreen> {
  final SOSRepository _repo = SOSRepository();
  final MapController _mapController = MapController();
  EmergencyCaseModel? _case;
  String _status = 'driver_assigned';
  bool _loading = true;
  bool _busy = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    // Attach the caseId so the driver's location stream powers patient/hospital ETA.
    final broadcaster = ref.read(driverLocationBroadcasterProvider);
    broadcaster.updateActiveCaseId(widget.caseId);
    if (!broadcaster.isBroadcasting) {
      broadcaster.startBroadcasting(caseId: widget.caseId);
    }
    _loadCase();
  }

  Future<void> _loadCase() async {
    try {
      final c = await _repo.getCaseDetails(widget.caseId);
      if (!mounted) return;
      setState(() {
        _case = c;
        _status = c.status;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _advance(String toStatus) async {
    setState(() => _busy = true);
    try {
      await _repo.updateCaseStatus(widget.caseId, toStatus);
      if (!mounted) return;
      setState(() {
        _status = toStatus;
        _busy = false;
      });
      if (toStatus == 'completed') _onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _onCompleted() {
    ref.read(driverLocationBroadcasterProvider).updateActiveCaseId(null);
    setState(() => _completed = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go(Routes.driverHome);
    });
  }

  Future<void> _callPatient() async {
    final phone = _case?.patientPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  ({String label, String next})? _nextAction() {
    switch (_status) {
      case 'driver_assigned':
        return (label: 'I Have Arrived', next: 'arrived');
      case 'arrived':
        return (label: 'Patient in Ambulance — Start Trip', next: 'en_route');
      case 'en_route':
        return (label: 'Arrived at Hospital', next: 'completed');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.sosRed)),
      );
    }
    if (_completed) {
      return const _CompletedView();
    }

    final c = _case;
    final positionAsync = ref.watch(currentPositionStreamProvider);
    final driverPos = positionAsync.asData?.value;
    final driver = driverPos != null ? LatLng(driverPos.latitude, driverPos.longitude) : null;

    final goingToHospital = _status == 'en_route';
    final target = goingToHospital && c?.hospitalLat != null && c?.hospitalLng != null
        ? LatLng(c!.hospitalLat!, c.hospitalLng!)
        : (c != null ? LatLng(c.patientLat, c.patientLng) : null);

    final action = _nextAction();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: driver ?? target ?? const LatLng(25.3792, 68.3683), initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: AppConstants.mapTileUrl,
                userAgentPackageName: 'com.resqpk.resqpk_app',
              ),
              if (driver != null && target != null)
                PolylineLayer(polylines: [
                  Polyline(points: [driver, target], color: AppColors.infoBlue, strokeWidth: 4),
                ]),
              MarkerLayer(markers: [
                if (target != null)
                  Marker(
                    point: target,
                    width: 34,
                    height: 34,
                    child: Icon(
                      goingToHospital ? Icons.local_hospital : Icons.location_on,
                      color: goingToHospital ? AppColors.confirmedGreen : AppColors.sosRed,
                      size: 32,
                    ),
                  ),
                if (driver != null)
                  Marker(
                    point: driver,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(color: AppColors.infoBlue, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.airport_shuttle, color: Colors.white, size: 20),
                    ),
                  ),
              ]),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTwo,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderGlass),
                ),
                child: Text(
                  '${c?.patientName ?? 'Patient'} · ${(c?.urgencyLevel ?? 'emergency').toUpperCase()}',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ActionCard(
              instruction: goingToHospital ? 'Head to the hospital' : 'Head to the patient',
              bloodGroup: c?.bloodGroup,
              conditions: c?.chronicConditions,
              busy: _busy,
              actionLabel: action?.label,
              onAction: action == null ? null : () => _advance(action.next),
              onCallPatient: _callPatient,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String instruction;
  final String? bloodGroup;
  final List<String>? conditions;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onCallPatient;

  const _ActionCard({
    required this.instruction,
    required this.bloodGroup,
    required this.conditions,
    required this.busy,
    required this.actionLabel,
    required this.onAction,
    required this.onCallPatient,
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
              Text(instruction, style: AppTextStyles.subtitle),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (bloodGroup != null && bloodGroup!.isNotEmpty)
                    _chip('🩸 $bloodGroup', AppColors.sosRed),
                  if (conditions != null)
                    ...conditions!.take(2).map((c) => _chip(c, AppColors.warningAmber)),
                  const Spacer(),
                  IconButton(
                    onPressed: onCallPatient,
                    icon: const Icon(Icons.phone, color: AppColors.confirmedGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (busy || onAction == null) ? null : onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.confirmedGreen,
                    disabledBackgroundColor: AppColors.surfaceThree,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(actionLabel ?? 'Trip complete', style: AppTextStyles.buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
      );
}

class _CompletedView extends StatelessWidget {
  const _CompletedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.confirmedGreen, size: 80),
            const SizedBox(height: 16),
            Text('Trip completed', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text('Thank you! Returning to home...',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
