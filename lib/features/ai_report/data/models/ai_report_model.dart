import 'package:flutter/material.dart';

/// AI emergency report — parses both the DB row (snake_case, from GET
/// /api/ai/report) and the pipeline/socket payload (camelCase).
class AIReportModel {
  final String? id;
  final String caseId;
  final String? urgencyLevel; // 'critical' | 'moderate' | 'low' | 'unknown'
  final String? emergencyType;
  final String? consciousnessState;
  final List<String> keyObservations;
  final List<String> possibleConditions;
  final String? firstAidSuggestion;
  final String? hospitalPreparation;
  final List<String> medicationsMentioned;
  final List<String> allergiesActive;
  final String? detectedLanguage;
  final String? transcribedText;
  final int? generationTimeMs;
  final String generationStatus; // 'pending' | 'processing' | 'completed' | 'failed'
  final String? errorMessage;

  const AIReportModel({
    this.id,
    required this.caseId,
    this.urgencyLevel,
    this.emergencyType,
    this.consciousnessState,
    this.keyObservations = const [],
    this.possibleConditions = const [],
    this.firstAidSuggestion,
    this.hospitalPreparation,
    this.medicationsMentioned = const [],
    this.allergiesActive = const [],
    this.detectedLanguage,
    this.transcribedText,
    this.generationTimeMs,
    this.generationStatus = 'pending',
    this.errorMessage,
  });

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  static int? _int(dynamic v) => v == null ? null : int.tryParse(v.toString());

  factory AIReportModel.fromJson(Map<String, dynamic> json) {
    final report = json['report'] as Map<String, dynamic>?; // nested socket shape
    final j = report ?? json;
    return AIReportModel(
      id: (j['id'] ?? j['reportId'])?.toString(),
      caseId: (j['case_id'] ?? j['caseId'])?.toString() ?? '',
      urgencyLevel: (j['urgency_level'] ?? j['urgencyLevel'])?.toString(),
      emergencyType: (j['emergency_type'] ?? j['emergencyType'])?.toString(),
      consciousnessState: (j['consciousness_state'] ?? j['consciousnessState'])?.toString(),
      keyObservations: _list(j['key_observations'] ?? j['keyObservations']),
      possibleConditions: _list(j['possible_conditions'] ?? j['possibleConditions']),
      firstAidSuggestion: (j['first_aid_suggestion'] ?? j['firstAidSuggestion'])?.toString(),
      hospitalPreparation: (j['hospital_preparation'] ?? j['hospitalPreparation'])?.toString(),
      medicationsMentioned: _list(j['medications_mentioned'] ?? j['medicationsMentioned']),
      allergiesActive: _list(j['allergies_active'] ?? j['allergiesActive']),
      detectedLanguage:
          (j['input_language'] ?? j['detectedLanguage'] ?? j['inputLanguage'])?.toString(),
      transcribedText: (j['transcribed_text'] ?? j['transcribedText'])?.toString(),
      generationTimeMs: _int(j['generation_time_ms'] ?? j['generationTimeMs']),
      generationStatus: (j['generation_status'] ?? j['generationStatus'])?.toString() ?? 'pending',
      errorMessage: (j['error_message'] ?? j['errorMessage'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'case_id': caseId,
        'urgency_level': urgencyLevel,
        'emergency_type': emergencyType,
        'consciousness_state': consciousnessState,
        'key_observations': keyObservations,
        'possible_conditions': possibleConditions,
        'first_aid_suggestion': firstAidSuggestion,
        'hospital_preparation': hospitalPreparation,
        'medications_mentioned': medicationsMentioned,
        'allergies_active': allergiesActive,
        'input_language': detectedLanguage,
        'transcribed_text': transcribedText,
        'generation_time_ms': generationTimeMs,
        'generation_status': generationStatus,
        'error_message': errorMessage,
      };

  AIReportModel copyWith({
    String? id,
    String? caseId,
    String? urgencyLevel,
    String? emergencyType,
    String? consciousnessState,
    List<String>? keyObservations,
    List<String>? possibleConditions,
    String? firstAidSuggestion,
    String? hospitalPreparation,
    List<String>? medicationsMentioned,
    List<String>? allergiesActive,
    String? detectedLanguage,
    String? transcribedText,
    int? generationTimeMs,
    String? generationStatus,
    String? errorMessage,
  }) {
    return AIReportModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      emergencyType: emergencyType ?? this.emergencyType,
      consciousnessState: consciousnessState ?? this.consciousnessState,
      keyObservations: keyObservations ?? this.keyObservations,
      possibleConditions: possibleConditions ?? this.possibleConditions,
      firstAidSuggestion: firstAidSuggestion ?? this.firstAidSuggestion,
      hospitalPreparation: hospitalPreparation ?? this.hospitalPreparation,
      medicationsMentioned: medicationsMentioned ?? this.medicationsMentioned,
      allergiesActive: allergiesActive ?? this.allergiesActive,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      transcribedText: transcribedText ?? this.transcribedText,
      generationTimeMs: generationTimeMs ?? this.generationTimeMs,
      generationStatus: generationStatus ?? this.generationStatus,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Color get urgencyColor {
    switch (urgencyLevel) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'moderate':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get urgencyLabel => urgencyLevel?.toUpperCase() ?? 'UNKNOWN';

  bool get isComplete => generationStatus == 'completed';
  bool get isFailed => generationStatus == 'failed';
  bool get isProcessing => generationStatus == 'processing';
}
