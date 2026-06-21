double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

List<String> _toStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return <String>[];
}

class MedicalProfileModel {
  final String id;
  final String userId;
  final String? bloodGroup;
  final DateTime? dateOfBirth;
  final String? gender;
  final double? weightKg;
  final double? heightCm;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final List<String> allergies;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;
  final String? additionalNotes;

  const MedicalProfileModel({
    required this.id,
    required this.userId,
    this.bloodGroup,
    this.dateOfBirth,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.chronicConditions = const [],
    this.currentMedications = const [],
    this.allergies = const [],
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
    this.additionalNotes,
  });

  factory MedicalProfileModel.fromJson(Map<String, dynamic> json) {
    return MedicalProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      bloodGroup: json['blood_group']?.toString(),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      gender: json['gender']?.toString(),
      weightKg: _toDoubleOrNull(json['weight_kg']),
      heightCm: _toDoubleOrNull(json['height_cm']),
      chronicConditions: _toStringList(json['chronic_conditions']),
      currentMedications: _toStringList(json['current_medications']),
      allergies: _toStringList(json['allergies']),
      emergencyContactName: json['emergency_contact_name']?.toString(),
      emergencyContactPhone: json['emergency_contact_phone']?.toString(),
      emergencyContactRelation: json['emergency_contact_relation']?.toString(),
      additionalNotes: json['additional_notes']?.toString(),
    );
  }

  /// Serializes only the fields the user actually set, so a partial update
  /// never clobbers existing data on the backend.
  Map<String, dynamic> toJson() => {
        if (bloodGroup != null) 'blood_group': bloodGroup,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String(),
        if (gender != null) 'gender': gender,
        if (weightKg != null) 'weight_kg': weightKg,
        if (heightCm != null) 'height_cm': heightCm,
        if (chronicConditions.isNotEmpty) 'chronic_conditions': chronicConditions,
        if (currentMedications.isNotEmpty) 'current_medications': currentMedications,
        if (allergies.isNotEmpty) 'allergies': allergies,
        if (emergencyContactName != null) 'emergency_contact_name': emergencyContactName,
        if (emergencyContactPhone != null) 'emergency_contact_phone': emergencyContactPhone,
        if (emergencyContactRelation != null)
          'emergency_contact_relation': emergencyContactRelation,
        if (additionalNotes != null) 'additional_notes': additionalNotes,
      };

  bool get isComplete => bloodGroup != null && bloodGroup!.isNotEmpty;

  MedicalProfileModel copyWith({
    String? id,
    String? userId,
    String? bloodGroup,
    DateTime? dateOfBirth,
    String? gender,
    double? weightKg,
    double? heightCm,
    List<String>? chronicConditions,
    List<String>? currentMedications,
    List<String>? allergies,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? additionalNotes,
  }) {
    return MedicalProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      currentMedications: currentMedications ?? this.currentMedications,
      allergies: allergies ?? this.allergies,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      additionalNotes: additionalNotes ?? this.additionalNotes,
    );
  }
}
