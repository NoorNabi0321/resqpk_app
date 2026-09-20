import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/driver_history_model.dart';

class DriverRepository {
  /// GET /api/cases/driver/history — this driver's runs and their numbers.
  Future<DriverHistory> getHistory({int limit = 30}) async {
    try {
      final res = await apiClient.get(
        '/api/cases/driver/history',
        queryParameters: {'limit': limit},
      );
      final data = res['data'];
      if (data is! Map) return const DriverHistory(trips: [], stats: DriverStats());

      final cases = data['cases'];
      final stats = data['stats'];

      return DriverHistory(
        trips: cases is List
            ? cases
                .whereType<Map>()
                .map((c) => DriverTrip.fromJson(Map<String, dynamic>.from(c)))
                .toList()
            : const [],
        stats: stats is Map
            ? DriverStats.fromJson(Map<String, dynamic>.from(stats))
            : const DriverStats(),
      );
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return e.message ?? 'Network error';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
