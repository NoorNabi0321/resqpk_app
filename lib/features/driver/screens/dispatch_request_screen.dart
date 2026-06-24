import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../sos/data/models/dispatch_request_model.dart';
import '../../sos/data/sos_repository.dart';

/// Full-screen interrupt shown to a driver when a dispatch request arrives.
/// Pops with 'accepted' | 'declined' | 'timeout' | 'expired' | 'error'.
class DispatchRequestScreen extends StatefulWidget {
  final DispatchRequestModel request;

  const DispatchRequestScreen({super.key, required this.request});

  @override
  State<DispatchRequestScreen> createState() => _DispatchRequestScreenState();
}

class _DispatchRequestScreenState extends State<DispatchRequestScreen> {
  final SOSRepository _repo = SOSRepository();
  Timer? _timer;
  int _remainingMs = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _remainingMs = widget.request.timeoutMs;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _remainingMs -= 100);
      if (_remainingMs <= 0) _respondAndPop('declined', 'timeout');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _respondAndPop(String response, String popResult) async {
    if (_busy) return;
    _busy = true;
    _timer?.cancel();
    try {
      final ok = await _repo.respondToDispatch(widget.request.caseId, response);
      if (!mounted) return;
      Navigator.of(context).pop(response == 'accepted' && !ok ? 'expired' : popResult);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop('error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final remainingSeconds = (_remainingMs / 1000).ceil().clamp(0, 99);
    final progress = (widget.request.timeoutMs > 0)
        ? (_remainingMs / widget.request.timeoutMs).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3121C), AppColors.sosRed],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.emergency_share, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text('Emergency Request',
                    style: AppTextStyles.display.copyWith(color: Colors.white, fontSize: 26)),
                Text(r.caseNumber,
                    style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 190,
                    child: AbsorbPointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(r.patientLat, r.patientLng),
                          initialZoom: 15,
                          interactionOptions:
                              const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: AppConstants.mapTileUrl,
                            userAgentPackageName: 'com.resqpk.resqpk_app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(r.patientLat, r.patientLng),
                                width: 26,
                                height: 26,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.sosRed,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(r.distanceText,
                    style: AppTextStyles.display.copyWith(color: Colors.white, fontSize: 30)),
                Text('${r.patientName} needs help',
                    style: AppTextStyles.body.copyWith(color: Colors.white)),
                const Spacer(),
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Text('$remainingSeconds',
                          style: AppTextStyles.display.copyWith(color: Colors.white, fontSize: 30)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _respondAndPop('declined', 'declined'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('DECLINE',
                            style: AppTextStyles.buttonLabel.copyWith(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _respondAndPop('accepted', 'accepted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.confirmedGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('ACCEPT', style: AppTextStyles.buttonLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
