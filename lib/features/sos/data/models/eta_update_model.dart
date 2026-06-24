double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _i(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

/// Live ETA update from the eta:update event.
class EtaUpdateModel {
  final String caseId;
  final String driverId;
  final double driverLat;
  final double driverLng;
  final int durationSeconds;
  final String durationText;
  final int distanceMeters;
  final String distanceText;
  final String phase; // 'to_patient' or 'to_hospital'
  final DateTime timestamp;

  EtaUpdateModel({
    required this.caseId,
    required this.driverId,
    required this.driverLat,
    required this.driverLng,
    required this.durationSeconds,
    required this.durationText,
    required this.distanceMeters,
    required this.distanceText,
    required this.phase,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory EtaUpdateModel.fromJson(Map<String, dynamic> json) {
    return EtaUpdateModel(
      caseId: json['caseId']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      driverLat: _d(json['driverLat']),
      driverLng: _d(json['driverLng']),
      durationSeconds: _i(json['durationSeconds']),
      durationText: json['durationText']?.toString() ?? '',
      distanceMeters: _i(json['distanceMeters']),
      distanceText: json['distanceText']?.toString() ?? '',
      phase: json['phase']?.toString() ?? 'to_patient',
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString()) : null,
    );
  }

  /// Estimated clock time of arrival, e.g. "2:34 PM".
  String get etaClockTime {
    final arrival = DateTime.now().add(Duration(seconds: durationSeconds));
    final hour12 = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
    final minute = arrival.minute.toString().padLeft(2, '0');
    final period = arrival.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
}
