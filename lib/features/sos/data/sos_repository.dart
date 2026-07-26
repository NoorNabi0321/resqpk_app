import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/emergency_case_model.dart';
import 'models/quick_message_model.dart';

class SOSRepository {
  // POST /api/sos/trigger — returns a (partial) case with id/status/hospital.
  Future<EmergencyCaseModel> triggerSOS({
    required double lat,
    required double lng,
    double? accuracy,
    String? address,
    String triggerMethod = 'app_sos',
  }) async {
    try {
      final res = await apiClient.post('/api/sos/trigger', data: {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
        if (address != null && address.isNotEmpty) 'address': address,
        'triggerMethod': triggerMethod,
      });
      return EmergencyCaseModel.fromJson(_data(res));
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // POST /api/sos/cancel
  Future<void> cancelSOS(String caseId, {String reason = 'false_alarm'}) async {
    try {
      await apiClient.post('/api/sos/cancel', data: {'caseId': caseId, 'reason': reason});
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // POST /api/cases/respond → true on success
  Future<bool> respondToDispatch(String caseId, String response) async {
    try {
      final res = await apiClient.post(
        '/api/cases/respond',
        data: {'caseId': caseId, 'response': response},
      );
      return res['success'] == true;
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // PUT /api/cases/status
  Future<void> updateCaseStatus(String caseId, String status) async {
    try {
      await apiClient.put('/api/cases/status', data: {'caseId': caseId, 'status': status});
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // GET /api/cases/:id → full case with joined data
  Future<EmergencyCaseModel> getCaseDetails(String caseId) async {
    try {
      final res = await apiClient.get('/api/cases/$caseId');
      return EmergencyCaseModel.fromJson(_data(res));
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // GET /api/cases/:id/route → road-following polyline for the current leg.
  // Returns { leg, coordinates: [{lat,lng},...], durationSeconds, distanceMeters }
  Future<Map<String, dynamic>> getCaseRoute(String caseId) async {
    try {
      final res = await apiClient.get('/api/cases/$caseId/route');
      return _data(res);
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // GET /api/hospitals/nearby → emergency hospitals sorted by distance.
  Future<List<Map<String, dynamic>>> getNearbyHospitals(double lat, double lng) async {
    try {
      final res = await apiClient.get(
        '/api/hospitals/nearby',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final d = res['data'];
      if (d is List) return d.whereType<Map<String, dynamic>>().toList();
      return [];
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // PUT /api/cases/:id/hospital → change destination hospital mid-case.
  Future<Map<String, dynamic>> changeHospital(String caseId, String hospitalId) async {
    try {
      final res = await apiClient.put(
        '/api/cases/$caseId/hospital',
        data: {'hospitalId': hospitalId},
      );
      return _data(res);
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // GET /api/decisions/constants → preset messages (cached by the caller).
  Future<List<QuickMessage>> getMessageConstants() async {
    try {
      final res = await apiClient.get('/api/decisions/constants');
      final messages = _data(res)['quickMessages'];
      if (messages is Map) {
        return messages.values
            .whereType<Map>()
            .map((m) => QuickMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // POST /api/decisions/message
  Future<void> sendQuickMessage(String caseId, String messageKey) async {
    try {
      await apiClient.post(
        '/api/decisions/message',
        data: {'caseId': caseId, 'messageKey': messageKey},
      );
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // GET /api/decisions/messages/:caseId
  Future<List<CaseMessage>> getCaseMessages(String caseId) async {
    try {
      final res = await apiClient.get('/api/decisions/messages/$caseId');
      final list = res['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((m) => CaseMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // GET /api/cases/track/:token (public family tracking)
  Future<Map<String, dynamic>> getShareTracking(String shareToken) async {
    try {
      final res = await apiClient.get('/api/cases/track/$shareToken');
      return _data(res);
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is Map<String, dynamic>) return d;
    return res;
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
