import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import 'models/first_aid_guide_model.dart';

/// First aid content with offline-first caching: guides are fetched once and
/// kept in Hive so they're available with no internet (critical for SOS).
class FirstAidRepository {
  static const _hiveCacheBox = 'first_aid_cache';
  static const _cacheTimestampKey = 'first_aid_last_synced';
  static const _cacheDataKey = 'first_aid_guides_json';
  static const _maxCacheAgeHours = 24;

  Future<Box> _box() async {
    if (Hive.isBoxOpen(_hiveCacheBox)) return Hive.box(_hiveCacheBox);
    return Hive.openBox(_hiveCacheBox);
  }

  List<FirstAidGuideModel> _parse(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => FirstAidGuideModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FirstAidGuideModel>> getGuides({
    String language = 'en',
    bool forceRefresh = false,
  }) async {
    final box = await _box();
    final lastSynced = box.get(_cacheTimestampKey) as String?;
    final cachedJson = box.get(_cacheDataKey) as String?;

    final cacheFresh = lastSynced != null &&
        DateTime.now().difference(DateTime.parse(lastSynced)).inHours < _maxCacheAgeHours;

    // Fresh cache → return immediately (works fully offline).
    if (cacheFresh && cachedJson != null && !forceRefresh) {
      return _parse(cachedJson);
    }

    // Stale / forced / empty → try the network, fall back to cache on failure.
    try {
      final res = await apiClient.get('/api/first-aid');
      final guides = (res['data']?['guides'] as List?) ?? [];
      await box.put(_cacheDataKey, jsonEncode(guides));
      await box.put(_cacheTimestampKey, DateTime.now().toIso8601String());
      return guides
          .map((e) => FirstAidGuideModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('First aid fetch failed, using cache: $e');
      if (cachedJson != null) return _parse(cachedJson);
      return [];
    }
  }

  Future<FirstAidGuideModel?> getGuideBySlug(String slug) async {
    final box = await _box();
    final cachedJson = box.get(_cacheDataKey) as String?;
    if (cachedJson != null) {
      final match = _parse(cachedJson).where((g) => g.slug == slug);
      if (match.isNotEmpty) return match.first;
    }
    try {
      final res = await apiClient.get('/api/first-aid/$slug');
      final data = res['data'];
      if (data is Map<String, dynamic>) return FirstAidGuideModel.fromJson(data);
    } catch (e) {
      debugPrint('Guide fetch failed: $e');
    }
    return null;
  }

  /// Refreshes the cache if stale. Fire-and-forget on app start.
  Future<void> syncInBackground() async {
    final box = await _box();
    final lastSynced = box.get(_cacheTimestampKey) as String?;
    final stale = lastSynced == null ||
        DateTime.now().difference(DateTime.parse(lastSynced)).inHours >= _maxCacheAgeHours;
    if (stale) await getGuides(forceRefresh: true);
  }

  Future<bool> isCacheAvailable() async {
    final box = await _box();
    return box.get(_cacheDataKey) != null;
  }

  List<FirstAidGuideModel> searchGuides(
    List<FirstAidGuideModel> guides,
    String query,
    String language,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return guides;
    return guides.where((g) {
      if (g.getTitle(language).toLowerCase().contains(q)) return true;
      if (g.category.toLowerCase().contains(q)) return true;
      return g.getSteps(language).any((s) => s.instruction.toLowerCase().contains(q));
    }).toList();
  }

  List<FirstAidGuideModel> getRelevantGuides(
    List<FirstAidGuideModel> guides,
    String emergencyType,
  ) {
    final t = emergencyType.trim().toLowerCase();
    if (t.isEmpty) return const [];
    return guides.where((g) => g.emergencyTypes.any((e) => e.toLowerCase() == t)).toList();
  }
}
