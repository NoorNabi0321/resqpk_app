import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';


/// Caches the patient's last-known GPS in Hive every 5 minutes, so screens
/// such as Nearby Camps have a position right after a cold start, before the
/// first live fix arrives. Fully fault-tolerant — it must never crash the app.
class GPSPersistenceService {
  Timer? _persistenceTimer;
  bool _isRunning = false;

  static const _boxName = 'gps_cache';
  static const _latKey = 'last_lat';
  static const _lngKey = 'last_lng';
  static const _accuracyKey = 'last_accuracy';
  static const _timestampKey = 'last_gps_timestamp';
  static const _updateIntervalMinutes = 5;

  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  void startPersisting() {
    if (_isRunning) return;
    _isRunning = true;

    // Update immediately, then on a fixed interval.
    _updateLocationNow();
    _persistenceTimer = Timer.periodic(
      const Duration(minutes: _updateIntervalMinutes),
      (_) => _updateLocationNow(),
    );
  }

  Future<void> _updateLocationNow() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        await box.put(_latKey, position.latitude);
        await box.put(_lngKey, position.longitude);
        await box.put(_accuracyKey, position.accuracy);
        await box.put(_timestampKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      // Background service — never throw.
      debugPrint('GPS persistence error (non-fatal): $e');
    }
  }

  Map<String, dynamic>? getLastKnownLocation() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final lat = box.get(_latKey);
    final lng = box.get(_lngKey);
    if (lat == null || lng == null) return null;
    return {
      'lat': lat,
      'lng': lng,
      'accuracy': box.get(_accuracyKey),
      'timestamp': box.get(_timestampKey),
    };
  }

  DateTime? _lastTimestamp() {
    final loc = getLastKnownLocation();
    final ts = loc?['timestamp'];
    if (ts is! String) return null;
    return DateTime.tryParse(ts);
  }

  bool isLocationFresh() {
    final t = _lastTimestamp();
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(minutes: 30);
  }

  String getLocationAgeText() {
    final t = _lastTimestamp();
    if (t == null) return 'No location saved';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return 'Over 24 hours ago (may be inaccurate)';
  }

  void stopPersisting() {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _isRunning = false;
  }

  void dispose() => stopPersisting();
}
