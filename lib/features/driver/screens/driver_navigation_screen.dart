import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/map/resqpk_map.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/back_guard.dart';
import '../../sos/data/models/emergency_case_model.dart';
import '../../sos/data/models/quick_message_model.dart';
import '../../sos/data/sos_repository.dart';
import '../providers/driver_history_provider.dart';
import '../providers/driver_realtime_provider.dart';
import '../widgets/driver_chrome.dart';

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

  // Road-following route for the current leg.
  List<LatLng> _routePoints = [];
  Timer? _routeTimer;
  bool _fetchingRoute = false;
  StreamSubscription<Map<String, dynamic>>? _caseEvtSub;

  // v2 — quick messages.
  List<QuickMessage> _driverMessages = [];
  final List<CaseMessage> _messageLog = [];
  String? _sendingKey;
  String? _sentKey;
  int _unreadMessages = 0;

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
    _routeTimer = Timer.periodic(const Duration(seconds: 45), (_) => _fetchRoute());

    _loadMessages();

    // Hospital decisions are broadcast to the case room, so join it — without
    // this the driver only ever sees the original dispatch.
    ref.read(socketServiceProvider).driverJoinCase(widget.caseId);

    _caseEvtSub = ref.read(socketServiceProvider).caseUpdateStream.listen(_onCaseEvent);
  }

  void _onCaseEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    switch (data['event']?.toString()) {
      // Patient switched hospitals themselves — reload destination + route.
      case 'hospital_changed':
        _loadCase();
        _fetchRoute();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hospital changed to ${data['hospitalName'] ?? 'a new hospital'}')),
        );
        break;

      // The patient called it off. Without this the driver was left on a map,
      // navigating to an address nobody is waiting at, until they worked out
      // for themselves that something had changed and backed out by hand.
      case 'cancelled':
        ref.read(driverLocationBroadcasterProvider).updateActiveCaseId(null);
        context.go(Routes.driverCaseClosed, extra: data['reason']?.toString());
        break;

      // Another driver took over — this screen is no longer ours.
      case 'handoff_released':
        ref.read(driverLocationBroadcasterProvider).updateActiveCaseId(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Case handed over to ${data['newDriverName'] ?? 'another driver'}',
            ),
          ),
        );
        context.go(Routes.driverHome);
        break;

      case 'quick_message':
        final message = CaseMessage.fromJson(data);
        if (!message.isFromHospital) return; // our own message echoing back
        setState(() {
          _messageLog.add(message);
          _unreadMessages += 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            backgroundColor: Resq.surfaceAlt,
            content: Row(
              children: [
                const Icon(Icons.local_hospital, color: Resq.ready, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(message.messageText, style: ResqType.body(color: Resq.ink))),
              ],
            ),
          ),
        );
        break;

      default:
        break;
    }
  }

  // Loaded independently: if the presets fail the history should still show,
  // and vice versa. A single Future.wait would lose both on one failure.
  Future<void> _loadMessages() async {
    try {
      final presets = await _repo.getMessageConstants();
      if (mounted) {
        setState(() {
          _driverMessages = presets.where((m) => m.role == 'driver').toList();
        });
      }
    } catch (e) {
      debugPrint('Quick message presets unavailable: $e');
    }

    await _refreshMessageLog();
  }

  Future<void> _refreshMessageLog() async {
    try {
      final log = await _repo.getCaseMessages(widget.caseId);
      if (!mounted) return;
      setState(() {
        _messageLog
          ..clear()
          ..addAll(log);
      });
    } catch (e) {
      debugPrint('Message history unavailable: $e');
    }
  }

  Future<void> _sendMessage(String key) async {
    setState(() => _sendingKey = key);
    try {
      await _repo.sendQuickMessage(widget.caseId, key);
      if (!mounted) return;
      setState(() {
        _sendingKey = null;
        _sentKey = key;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _sentKey == key) setState(() => _sentKey = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openMessageLog() {
    setState(() => _unreadMessages = 0);
    // Pull the latest history each time — messages sent while the app was
    // backgrounded would otherwise be missing from the feed.
    _refreshMessageLog();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Resq.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Messages', style: ResqType.section(color: Resq.ink)),
              const SizedBox(height: 12),
              if (_messageLog.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No messages yet.',
                      textAlign: TextAlign.center, style: ResqType.caption(color: Resq.inkMuted)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _messageLog.length,
                    itemBuilder: (_, i) {
                      final m = _messageLog[i];
                      return Align(
                        alignment:
                            m.isFromHospital ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: m.isFromHospital
                                ? Resq.surfaceAlt
                                : Resq.info.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.messageText, style: ResqType.body(color: Resq.ink)),
                              if (m.createdAt != null)
                                Text(
                                  TimeOfDay.fromDateTime(m.createdAt!.toLocal()).format(context),
                                  style: ResqType.caption(color: Resq.inkMuted),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Hand the case to another nearby ambulance (breakdown, gridlock, etc.).
  Future<void> _confirmHandoff() async {
    final reasons = [
      'Stuck in heavy traffic',
      'Vehicle breakdown',
      'Too far to reach in time',
      'Other emergency',
    ];
    String? chosen;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Resq.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Hand over this case', style: ResqType.section(color: Resq.ink)),
                const SizedBox(height: 6),
                Text(
                  'The nearest available ambulance will take over. The patient '
                  'and hospital are told immediately.',
                  style: ResqType.caption(color: Resq.inkMuted),
                ),
                const SizedBox(height: 16),
                Text('Reason', style: ResqType.caption(color: Resq.inkMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons
                      .map(
                        (r) => GestureDetector(
                          onTap: () => setSheetState(() => chosen = r),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: chosen == r
                                  ? Resq.decision.withValues(alpha: 0.2)
                                  : Resq.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: chosen == r
                                    ? Resq.decision
                                    : Resq.border,
                              ),
                            ),
                            child: Text(
                              r,
                              style: ResqType.caption(color: Resq.inkMuted).copyWith(
                                color: chosen == r
                                    ? Resq.decision
                                    : Resq.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: chosen == null
                        ? null
                        : () => Navigator.of(sheetCtx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Resq.decision,
                      disabledBackgroundColor: Resq.surfaceAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text('Find another ambulance',
                        style: ResqType.button()),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                  child: Text('Keep this case', style: ResqType.caption(color: Resq.inkMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await _repo.handoffCase(widget.caseId, reason: chosen);
      if (!mounted) return;
      final newDriver = result['driver'] as Map<String, dynamic>?;
      ref.read(driverLocationBroadcasterProvider).updateActiveCaseId(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Handed over to ${newDriver?['fullName'] ?? 'another driver'}',
          ),
        ),
      );
      context.go(Routes.driverHome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // A redirect changes where this ambulance is going — it must be acknowledged,

  @override
  void dispose() {
    _routeTimer?.cancel();
    _caseEvtSub?.cancel();
    super.dispose();
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
      _fetchRoute();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchRoute() async {
    if (_fetchingRoute || _completed) return;
    _fetchingRoute = true;
    try {
      final route = await _repo.getCaseRoute(widget.caseId);
      final coords = (route['coordinates'] as List? ?? [])
          .whereType<Map>()
          .map((p) => LatLng(
                double.tryParse('${p['lat']}') ?? 0,
                double.tryParse('${p['lng']}') ?? 0,
              ))
          .toList();
      if (mounted) setState(() => _routePoints = coords);
    } catch (_) {
      // Straight-line fallback stays if routing is unavailable.
    } finally {
      _fetchingRoute = false;
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
        _routePoints = []; // leg changed — clear stale route until refetched
      });
      if (toStatus == 'completed') {
        _onCompleted();
      } else {
        _fetchRoute();
      }
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
    // The run just finished — the duty screen's "today" count is now wrong.
    ref.invalidate(driverHistoryProvider);
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
        backgroundColor: Resq.canvas,
        body: Center(child: CircularProgressIndicator(color: Resq.critical)),
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

    // Back returns to the driver home; the case stays assigned and can be
    // reopened from there or on the next app launch.
    return BackTo(
      onBack: () => context.go(Routes.driverHome),
      // The same theme the sheets and dialogs this screen opens will use, so a
      // handover sheet over the map is the same warm paper as everywhere else.
      child: Theme(
        data: ResqTheme.light,
        child: Scaffold(
      backgroundColor: Resq.canvas,
      body: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: driver ?? target ?? const LatLng(25.3792, 68.3683), initialZoom: 14),
            children: [
              const ResQPKTileLayer(light: true),
              PolylineLayer(polylines: [
                if (_routePoints.length >= 2)
                  ...routePolyline(
                    _routePoints,
                    color: goingToHospital ? Resq.ready : Resq.info,
                  )
                else if (driver != null && target != null)
                  ...routePolyline([driver, target],
                      color: Resq.info, isAlternate: true),
              ]),
              MarkerLayer(markers: [
                if (target != null)
                  Marker(
                    point: target,
                    width: MapSpec.touchTarget,
                    height: MapSpec.pinHeight,
                    alignment: Alignment.topCenter,
                    child: MapDestinationPin(
                      color: goingToHospital ? Resq.ready : Resq.critical,
                      icon: goingToHospital ? Icons.local_hospital : Icons.person_pin_circle,
                    ),
                  ),
                if (driver != null)
                  Marker(
                    point: driver,
                    width: MapSpec.touchTarget,
                    height: MapSpec.touchTarget,
                    child: const NavigationPuck(
                      color: Resq.info,
                      icon: Icons.navigation,
                    ),
                  ),
              ]),
            ],
          ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 12),
                    // Back to the driver home; the case stays assigned and the
                    // driver can reopen it from there.
                    _RoundIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => context.go(Routes.driverHome),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Resq.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Resq.border),
                        ),
                        child: Text(
                          '${c?.patientName ?? 'Patient'} · ${(c?.urgencyLevel ?? 'emergency').toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: ResqType.caption(color: Resq.inkMuted),
                        ),
                      ),
                    ),
                    _MessageLogButton(unread: _unreadMessages, onTap: _openMessageLog),
                    const SizedBox(width: 8),
                    if (_status == 'driver_assigned' || _status == 'arrived')
                      _RoundIconButton(
                        icon: Icons.swap_horiz,
                        tint: Resq.decision,
                        onTap: _busy ? null : _confirmHandoff,
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
                _DestinationBanner(hospitalName: c?.hospitalName),
              ],
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
              quickMessages: _driverMessages,
              sendingKey: _sendingKey,
              sentKey: _sentKey,
              onSendMessage: _sendMessage,
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}

/// Thin strip under the patient pill: where this ambulance is taking them.
///
/// It used to report what the hospital had decided — "Hospital reviewing…"
/// until a ward pressed accept. Nothing decides now, so the strip says the one
/// thing a driver needs off it: the destination.
class _DestinationBanner extends StatelessWidget {
  final String? hospitalName;

  const _DestinationBanner({required this.hospitalName});

  @override
  Widget build(BuildContext context) {
    final named = hospitalName != null && hospitalName!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: named ? Resq.ready.withValues(alpha: 0.92) : Resq.surfaceAlt.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: named ? Resq.ready : Resq.border),
      ),
      width: double.infinity,
      child: Text(
        named ? '$hospitalName is expecting you' : 'Destination not chosen yet',
        textAlign: TextAlign.center,
        style: ResqType.caption(color: named ? Colors.white : Resq.inkMuted)
            .copyWith(fontWeight: named ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }
}

/// Circular translucent button used for the top-bar controls.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? tint;

  const _RoundIconButton({required this.icon, required this.onTap, this.tint});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Resq.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: tint ?? Resq.border),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Resq.inkMuted : (tint ?? Resq.inkMuted),
          size: 20,
        ),
      ),
    );
  }
}

/// Envelope with an unread badge — opens the timestamped message feed.
class _MessageLogButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _MessageLogButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Resq.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: Resq.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.mail_outline, color: Resq.inkMuted, size: 20),
            if (unread > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Resq.critical,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: ResqType.caption(color: Resq.inkMuted).copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
  final List<QuickMessage> quickMessages;
  final String? sendingKey;
  final String? sentKey;
  final ValueChanged<String> onSendMessage;

  const _ActionCard({
    required this.instruction,
    required this.bloodGroup,
    required this.conditions,
    required this.busy,
    required this.actionLabel,
    required this.onAction,
    required this.onCallPatient,
    required this.quickMessages,
    required this.sendingKey,
    required this.sentKey,
    required this.onSendMessage,
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
            color: Resq.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Resq.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(instruction, style: ResqType.section(color: Resq.ink)),
              const SizedBox(height: 12),
              if (quickMessages.isNotEmpty) ...[
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: quickMessages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final m = quickMessages[i];
                      final sending = sendingKey == m.key;
                      final sent = sentKey == m.key;
                      return GestureDetector(
                        onTap: sending ? null : () => onSendMessage(m.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sent
                                ? Resq.ready.withValues(alpha: 0.2)
                                : Resq.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: sent ? Resq.ready : Resq.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sending)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Resq.inkMuted,
                                  ),
                                )
                              else if (sent)
                                const Icon(Icons.check,
                                    size: 13, color: Resq.ready),
                              if (sending || sent) const SizedBox(width: 6),
                              Text(
                                m.text,
                                style: ResqType.caption(color: Resq.inkMuted).copyWith(
                                  color: sent
                                      ? Resq.ready
                                      : Resq.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (bloodGroup != null && bloodGroup!.isNotEmpty)
                    _chip('🩸 $bloodGroup', Resq.critical),
                  if (conditions != null)
                    ...conditions!.take(2).map((c) => _chip(c, Resq.decision)),
                  const Spacer(),
                  IconButton(
                    onPressed: onCallPatient,
                    icon: const Icon(Icons.phone, color: Resq.ready),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // The only button on this screen a moving driver should ever have
              // to find: full width, 56dp, and it says what happens next.
              DriverButton(
                label: actionLabel ?? 'Trip complete',
                icon: Icons.arrow_forward_rounded,
                busy: busy,
                onPressed: onAction,
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
        child: Text(label, style: ResqType.caption(color: Resq.inkMuted).copyWith(color: color)),
      );
}

class _CompletedView extends StatelessWidget {
  const _CompletedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Resq.canvas,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Resq.ready, size: 80),
            const SizedBox(height: 16),
            Text('Trip completed', style: ResqType.title(color: Resq.ink)),
            const SizedBox(height: 8),
            Text('Thank you! Returning to home...',
                style: ResqType.body(color: Resq.ink).copyWith(color: Resq.inkMuted)),
          ],
        ),
      ),
    );
  }
}
