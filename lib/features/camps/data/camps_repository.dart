import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import 'models/camp_model.dart';

/// Nearby camps with an offline fallback. Camps change slowly, so serving a
/// stale cached list beats showing nothing when the network is down.
class CampsRepository {
  static const _boxName = 'camps_cache';
  static const _dataKey = 'camps_json';
  static const _timestampKey = 'camps_last_synced';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  List<CampModel> _parse(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => CampModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// GET /api/camps/nearby — falls back to the last successful response.
  Future<List<CampModel>> getNearbyCamps(double lat, double lng) async {
    final box = await _box();
    try {
      final res = await apiClient.get(
        '/api/camps/nearby',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final list = (res['data'] as List?) ?? [];
      await box.put(_dataKey, jsonEncode(list));
      await box.put(_timestampKey, DateTime.now().toIso8601String());
      return list
          .whereType<Map>()
          .map((e) => CampModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      final cached = box.get(_dataKey) as String?;
      if (cached != null) return _parse(cached);
      if (e is DioException) throw Exception(e.message ?? 'Could not load camps');
      rethrow;
    }
  }

  /// GET /api/camps/:id/route — the road line from here to the camp.
  ///
  /// Never throws. A camp with no route still has a pin, and a straight line
  /// to it points the right way, which is better than an error where a map
  /// should be.
  Future<List<({double lat, double lng})>> getRouteToCamp(
    String campId,
    double fromLat,
    double fromLng,
  ) async {
    try {
      final res = await apiClient.get(
        '/api/camps/$campId/route',
        queryParameters: {'lat': fromLat, 'lng': fromLng},
      );
      final coords = (res['data']?['coordinates'] as List?) ?? [];
      return coords
          .whereType<Map>()
          .map((p) => (
                lat: double.tryParse('${p['lat']}') ?? 0,
                lng: double.tryParse('${p['lng']}') ?? 0,
              ))
          .where((p) => p.lat != 0 && p.lng != 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// True when the list currently on screen came from the cache, so the UI can
  /// say so rather than implying the data is live.
  Future<bool> isServingCache() async {
    final box = await _box();
    final last = box.get(_timestampKey) as String?;
    if (last == null) return false;
    return DateTime.now().difference(DateTime.parse(last)).inMinutes > 5;
  }

  Future<DateTime?> lastSyncedAt() async {
    final box = await _box();
    final last = box.get(_timestampKey) as String?;
    return last == null ? null : DateTime.tryParse(last);
  }
}
