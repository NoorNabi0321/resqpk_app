double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _i(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

/// Incoming dispatch request shown to a driver (from the emergency:case_created event).
class DispatchRequestModel {
  final String caseId;
  final String caseNumber;
  final String patientName;
  final double patientLat;
  final double patientLng;
  final int distanceMeters;
  final String distanceText;
  final int timeoutMs;
  final DateTime receivedAt;

  DispatchRequestModel({
    required this.caseId,
    required this.caseNumber,
    required this.patientName,
    required this.patientLat,
    required this.patientLng,
    required this.distanceMeters,
    required this.distanceText,
    required this.timeoutMs,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory DispatchRequestModel.fromJson(Map<String, dynamic> json) {
    return DispatchRequestModel(
      caseId: json['caseId']?.toString() ?? '',
      caseNumber: json['caseNumber']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? 'Patient',
      patientLat: _d(json['patientLat']),
      patientLng: _d(json['patientLng']),
      distanceMeters: _i(json['distanceMeters']),
      distanceText: json['distanceText']?.toString() ?? '',
      timeoutMs: json['timeoutMs'] == null ? 15000 : _i(json['timeoutMs']),
    );
  }
}
