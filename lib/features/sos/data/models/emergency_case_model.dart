double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _i(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

List<String> _list(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const <String>[];

/// Represents an emergency case. fromJson handles the GET /api/cases/:id
/// response (snake_case + embedded patient/driver/hospital/ai_report) and is
/// tolerant of camelCase socket payloads.
class EmergencyCaseModel {
  final String id;
  final String caseNumber;
  final String patientId;
  final String? patientName;
  final String? patientPhone;
  final String? driverId;
  final String? hospitalId;
  final String status;
  final String triggerMethod;
  final double patientLat;
  final double patientLng;
  final String? patientAddress;
  final DateTime sosTriggeredAt;
  final DateTime? driverAssignedAt;
  final int? estimatedDriverArrivalSeconds;
  final String? shareToken;
  final String? shareUrl;
  final String? urgencyLevel;
  final String? emergencyType;
  final bool hasAiReport;

  // Joined / live fields
  final String? driverName;
  final String? driverPhone;
  final String? vehicleNumber;
  final double? driverLat;
  final double? driverLng;
  final double? driverHeading;
  final String? hospitalName;
  final double? hospitalLat;
  final double? hospitalLng;
  final String? hospitalPhone;
  final String? bloodGroup;
  final List<String>? chronicConditions;
  final String? firstAidSuggestion;

  const EmergencyCaseModel({
    required this.id,
    required this.caseNumber,
    required this.patientId,
    this.patientName,
    this.patientPhone,
    this.driverId,
    this.hospitalId,
    required this.status,
    required this.triggerMethod,
    required this.patientLat,
    required this.patientLng,
    this.patientAddress,
    required this.sosTriggeredAt,
    this.driverAssignedAt,
    this.estimatedDriverArrivalSeconds,
    this.shareToken,
    this.shareUrl,
    this.urgencyLevel,
    this.emergencyType,
    this.hasAiReport = false,
    this.driverName,
    this.driverPhone,
    this.vehicleNumber,
    this.driverLat,
    this.driverLng,
    this.driverHeading,
    this.hospitalName,
    this.hospitalLat,
    this.hospitalLng,
    this.hospitalPhone,
    this.bloodGroup,
    this.chronicConditions,
    this.firstAidSuggestion,
  });

  factory EmergencyCaseModel.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final hospital = json['hospital'] as Map<String, dynamic>?;
    final patient = json['patient'] as Map<String, dynamic>?;
    final medical = patient?['medical_profiles'] as Map<String, dynamic>?;
    final ai = json['ai_report'] as Map<String, dynamic>?;

    return EmergencyCaseModel(
      id: (json['id'] ?? json['caseId'])?.toString() ?? '',
      caseNumber: (json['case_number'] ?? json['caseNumber'])?.toString() ?? '',
      patientId: (json['patient_id'] ?? json['patientId'])?.toString() ?? '',
      patientName: patient?['full_name']?.toString() ?? json['patientName']?.toString(),
      patientPhone: patient?['phone']?.toString() ?? json['patientPhone']?.toString(),
      driverId: (json['driver_id'] ?? json['driverId'])?.toString(),
      hospitalId: (json['hospital_id'] ?? json['hospitalId'])?.toString(),
      status: json['status']?.toString() ?? 'pending',
      triggerMethod: (json['trigger_method'] ?? json['triggerMethod'])?.toString() ?? 'app_sos',
      patientLat: _d(json['patient_lat'] ?? json['patientLat']) ?? 0,
      patientLng: _d(json['patient_lng'] ?? json['patientLng']) ?? 0,
      patientAddress: (json['patient_address'] ?? json['patientAddress'])?.toString(),
      sosTriggeredAt: _dt(json['sos_triggered_at']) ?? DateTime.now(),
      driverAssignedAt: _dt(json['driver_assigned_at']),
      estimatedDriverArrivalSeconds:
          _i(json['estimated_driver_arrival_seconds'] ?? json['etaSeconds']),
      shareToken: (json['share_token'] ?? json['shareToken'])?.toString(),
      shareUrl: json['shareUrl']?.toString(),
      urgencyLevel: (json['urgency_level'] ?? ai?['urgency_level'])?.toString(),
      emergencyType: (json['emergency_type'] ?? ai?['emergency_type'])?.toString(),
      hasAiReport: json['has_ai_report'] == true,
      driverName: driverUser?['full_name']?.toString() ?? driver?['fullName']?.toString(),
      driverPhone: driverUser?['phone']?.toString() ?? driver?['phone']?.toString(),
      vehicleNumber: (driver?['vehicle_number'] ?? driver?['vehicleNumber'])?.toString(),
      driverLat: _d(driver?['current_lat'] ?? driver?['currentLat']),
      driverLng: _d(driver?['current_lng'] ?? driver?['currentLng']),
      driverHeading: _d(driver?['heading']),
      hospitalName: hospital?['name']?.toString(),
      hospitalLat: _d(hospital?['lat']),
      hospitalLng: _d(hospital?['lng']),
      hospitalPhone: hospital?['emergency_phone']?.toString(),
      bloodGroup: medical?['blood_group']?.toString(),
      chronicConditions: medical == null ? null : _list(medical['chronic_conditions']),
      firstAidSuggestion: ai?['first_aid_suggestion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'case_number': caseNumber,
        'patient_id': patientId,
        'driver_id': driverId,
        'hospital_id': hospitalId,
        'status': status,
        'trigger_method': triggerMethod,
        'patient_lat': patientLat,
        'patient_lng': patientLng,
        'patient_address': patientAddress,
        'estimated_driver_arrival_seconds': estimatedDriverArrivalSeconds,
        'share_token': shareToken,
        'urgency_level': urgencyLevel,
        'emergency_type': emergencyType,
        'has_ai_report': hasAiReport,
      };

  EmergencyCaseModel copyWith({
    String? status,
    String? driverId,
    int? estimatedDriverArrivalSeconds,
    String? shareToken,
    String? shareUrl,
    String? urgencyLevel,
    String? emergencyType,
    bool? hasAiReport,
    String? driverName,
    String? driverPhone,
    String? vehicleNumber,
    double? driverLat,
    double? driverLng,
    double? driverHeading,
    String? hospitalName,
    String? hospitalPhone,
  }) {
    return EmergencyCaseModel(
      id: id,
      caseNumber: caseNumber,
      patientId: patientId,
      patientName: patientName,
      patientPhone: patientPhone,
      driverId: driverId ?? this.driverId,
      hospitalId: hospitalId,
      status: status ?? this.status,
      triggerMethod: triggerMethod,
      patientLat: patientLat,
      patientLng: patientLng,
      patientAddress: patientAddress,
      sosTriggeredAt: sosTriggeredAt,
      driverAssignedAt: driverAssignedAt,
      estimatedDriverArrivalSeconds:
          estimatedDriverArrivalSeconds ?? this.estimatedDriverArrivalSeconds,
      shareToken: shareToken ?? this.shareToken,
      shareUrl: shareUrl ?? this.shareUrl,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      emergencyType: emergencyType ?? this.emergencyType,
      hasAiReport: hasAiReport ?? this.hasAiReport,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      driverHeading: driverHeading ?? this.driverHeading,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalLat: hospitalLat,
      hospitalLng: hospitalLng,
      hospitalPhone: hospitalPhone ?? this.hospitalPhone,
      bloodGroup: bloodGroup,
      chronicConditions: chronicConditions,
      firstAidSuggestion: firstAidSuggestion,
    );
  }
}
