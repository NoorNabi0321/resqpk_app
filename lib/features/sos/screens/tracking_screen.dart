import 'dart:async';
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
import '../../ai_report/data/models/ai_report_model.dart';
import '../../ai_report/providers/ai_report_provider.dart';
import '../../ai_report/widgets/first_aid_suggestion_card.dart';
import '../../first_aid/providers/first_aid_provider.dart';
import '../data/sos_repository.dart';
import '../providers/sos_provider.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  final SOSRepository _repo = SOSRepository();
  LatLng? _driverPos;
  double _driverHeading = 0;
  int? _originalEtaSeconds;

  // Road-following route for the current leg (from /api/cases/:id/route).
  List<LatLng> _routePoints = [];
  String? _routeLeg;
  Timer? _routeTimer;
  bool _fetchingRoute = false;

  bool _showFirstAidCard = false;
  AIReportModel? _latestReport;
  StreamSubscription<Map<String, dynamic>>? _aiSub;

  // v2 — brief banner when the hospital reroutes the ambulance.
  String? _hospitalChangeBanner;
  Timer? _bannerTimer;
  StreamSubscription<Map<String, dynamic>>? _decisionSub;

  @override
  void initState() {
    super.initState();
    final c = ref.read(sosProvider).activeCase;
    if (c?.driverLat != null && c?.driverLng != null) {
      _driverPos = LatLng(c!.driverLat!, c.driverLng!);
      _driverHeading = c.driverHeading ?? 0;
    }
    _originalEtaSeconds = c?.estimatedDriverArrivalSeconds;

    // Surface first-aid guidance the moment the AI report is ready.
    _aiSub = ref.read(socketServiceProvider).aiReportStream.listen((evt) {
      if (evt['event'] == 'report_ready' && mounted) {
        setState(() {
          _latestReport = AIReportModel.fromJson(evt);
          _showFirstAidCard = true;
        });
      }
    });

    // Fetch the road route now and refresh it as the driver moves.
    _fetchRoute();
    _routeTimer = Timer.periodic(const Duration(seconds: 45), (_) => _fetchRoute());

    // A redirect changes the destination — reassure the patient without
    // surfacing the clinical reason, which is for the driver and records only.
    _decisionSub = ref.read(socketServiceProvider).caseUpdateStream.listen((data) {
      if (data['event'] != 'hospital_redirected' || !mounted) return;
      final newHospital = data['newHospital'] as Map<String, dynamic>?;
      final name = newHospital?['name']?.toString() ?? 'another hospital';
      setState(() {
        _hospitalChangeBanner = 'Hospital changed to $name for better care availability.';
      });
      _fetchRoute();
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _hospitalChangeBanner = null);
      });
    });
  }

  Future<void> _fetchRoute() async {
    final caseId = ref.read(sosProvider).activeCaseId;
    if (caseId == null || _fetchingRoute) return;
    _fetchingRoute = true;
    try {
      final route = await _repo.getCaseRoute(caseId);
      final coords = (route['coordinates'] as List? ?? [])
          .whereType<Map>()
          .map((p) => LatLng(
                double.tryParse('${p['lat']}') ?? 0,
                double.tryParse('${p['lng']}') ?? 0,
              ))
          .toList();
      if (mounted) {
        setState(() {
          _routePoints = coords;
          _routeLeg = route['leg']?.toString();
        });
      }
    } catch (_) {
      // Straight-line fallback stays on screen if routing is unavailable.
    } finally {
      _fetchingRoute = false;
    }
  }

  Future<void> _openChangeHospitalSheet() async {
    final c = ref.read(sosProvider).activeCase;
    if (c == null) return;
    List<Map<String, dynamic>> hospitals = [];
    try {
      hospitals = await _repo.getNearbyHospitals(c.patientLat, c.patientLng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load hospitals: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
      return;
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceOne,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('Choose hospital', style: AppTextStyles.subtitle),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hospitals.length,
                itemBuilder: (_, i) {
                  final h = hospitals[i];
                  final id = h['id']?.toString() ?? '';
                  final isCurrent = id == ref.read(sosProvider).activeCase?.hospitalId;
                  return ListTile(
                    leading: Icon(
                      Icons.local_hospital,
                      color: isCurrent ? AppColors.confirmedGreen : AppColors.textSecondary,
                    ),
                    title: Text(h['name']?.toString() ?? 'Hospital', style: AppTextStyles.body),
                    subtitle: Text(
                      '${h['distanceText'] ?? ''} · ${h['address'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle, color: AppColors.confirmedGreen, size: 20)
                        : null,
                    onTap: isCurrent
                        ? null
                        : () {
                            Navigator.of(sheetCtx).pop();
                            _changeHospital(h);
                          },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _changeHospital(Map<String, dynamic> hospital) async {
    final caseId = ref.read(sosProvider).activeCaseId;
    final id = hospital['id']?.toString();
    if (caseId == null || id == null) return;
    try {
      await _repo.changeHospital(caseId, id);
      ref.read(sosProvider.notifier).applyHospitalChange(
            id: id,
            name: hospital['name']?.toString(),
            lat: double.tryParse('${hospital['lat']}'),
            lng: double.tryParse('${hospital['lng']}'),
          );
      _fetchRoute();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hospital changed to ${hospital['name']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  void dispose() {
    _aiSub?.cancel();
    _decisionSub?.cancel();
    _routeTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
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

    // Refetch the road route whenever the leg changes (status transition) or
    // the destination hospital is switched.
    ref.listen(
      sosProvider.select((s) => '${s.status}:${s.activeCase?.hospitalId}'),
      (_, __) => _fetchRoute(),
    );

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
                  // Road-following route for the current leg (pickup = blue
                  // driver→patient; dropoff = green →hospital). Falls back to a
                  // straight line only while the road route hasn't loaded yet.
                  if (_routePoints.length >= 2)
                    Polyline(
                      points: _routePoints,
                      color: _routeLeg == 'dropoff'
                          ? AppColors.confirmedGreen
                          : AppColors.infoBlue,
                      strokeWidth: 5,
                    )
                  else if (_routeLeg != 'dropoff' && driver != null)
                    Polyline(points: [driver, patient], color: AppColors.infoBlue, strokeWidth: 4)
                  else if (_routeLeg == 'dropoff' && hospital != null)
                    Polyline(
                      points: [patient, hospital],
                      color: AppColors.confirmedGreen.withValues(alpha: 0.7),
                      strokeWidth: 4,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hospitalChangeBanner != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.infoBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.infoBlue, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _hospitalChangeBanner!,
                              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_showFirstAidCard && _latestReport?.firstAidSuggestion != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: FirstAidSuggestionCard(
                      suggestion: _latestReport!.firstAidSuggestion!,
                      urgencyLevel: _latestReport!.urgencyLevel ?? 'unknown',
                      onViewFullReport: () => context.push(Routes.aiReport, extra: c.id),
                      onSeeGuide: () {
                        final relevant = ref
                            .read(firstAidProvider.notifier)
                            .getRelevantGuidesForEmergency(_latestReport!.emergencyType ?? '');
                        if (relevant.isNotEmpty) {
                          context.push(Routes.guideDetail, extra: relevant.first);
                        } else {
                          context.push(Routes.firstAid);
                        }
                      },
                      onDismiss: () => setState(() => _showFirstAidCard = false),
                    ),
                  ),
                _StatusCard(
                  driverName: c.driverName ?? 'Driver',
                  vehicleNumber: c.vehicleNumber ?? '',
                  etaText: _etaText(eta, ref.watch(sosProvider).status),
                  progress: progress,
                  hospitalName: c.hospitalName ?? 'Hospital',
                  hasReport: _latestReport != null ||
                      (ref.watch(aiReportProvider).report?.isComplete ?? false),
                  onCallDriver: () => _call(c.driverPhone),
                  onAiReport: () => context.push(Routes.aiReport, extra: c.id),
                  onCancel: _confirmCancel,
                  onChangeHospital: _openChangeHospitalSheet,
                  hospitalConfirmed: ref.watch(sosProvider).isHospitalConfirmed,
                  preparationNote: ref.watch(sosProvider).hospitalPreparationNote,
                ),
              ],
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
  final bool hasReport;
  final VoidCallback onCallDriver;
  final VoidCallback onAiReport;
  final VoidCallback onCancel;
  final VoidCallback onChangeHospital;
  final bool hospitalConfirmed;
  final String? preparationNote;

  const _StatusCard({
    required this.driverName,
    required this.vehicleNumber,
    required this.etaText,
    required this.progress,
    required this.hospitalName,
    this.hasReport = false,
    required this.onCallDriver,
    required this.onAiReport,
    required this.onCancel,
    required this.onChangeHospital,
    this.hospitalConfirmed = false,
    this.preparationNote,
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
                  if (hospitalConfirmed)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.confirmedGreen.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.confirmedGreen),
                        ),
                        child: Text(
                          'Hospital confirmed ✓',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.confirmedGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: onChangeHospital,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Change',
                        style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue),
                      ),
                    ),
                ],
              ),
              if (hospitalConfirmed && preparationNote != null && preparationNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 26),
                  child: Text(preparationNote!, style: AppTextStyles.caption),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAiReport,
                icon: const Icon(Icons.smart_toy_outlined, color: AppColors.infoBlue, size: 18),
                label: Text(hasReport ? 'View Full Report' : 'Generate AI Report',
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
