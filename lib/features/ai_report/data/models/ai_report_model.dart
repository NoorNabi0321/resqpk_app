import 'package:flutter/material.dart';

import 'clarification_model.dart';

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
  /// Signed URL of the generated PDF (expires ~6h; refresh via the API).
  final String? pdfUrl;

  /// How well the input supported the report, 0 to 1. Null on older reports.
  final double? confidenceScore;

  /// 'none' | 'awaiting' | 'answered' | 'skipped'.
  ///
  /// Where the case got to in the question sequence that ran *before* this
  /// report was written. 'awaiting' means there is no report yet at all.
  final String clarificationState;

  /// The two to four single-tap questions put before the report was written,
  /// with the answers that fed it.
  final List<ClarificationModel> clarifications;

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
    this.pdfUrl,
    this.confidenceScore,
    this.clarificationState = 'none',
    this.clarifications = const [],
  });

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

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
      pdfUrl: (j['pdf_url'] ?? j['pdfUrl'])?.toString(),
      confidenceScore: _double(j['confidence_score'] ?? j['confidenceScore']),
      clarificationState:
          (j['clarification_state'] ?? j['clarificationState'])?.toString() ?? 'none',
      clarifications: ClarificationModel.listFrom(j['clarifications']),
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
        'confidence_score': confidenceScore,
        'clarification_state': clarificationState,
        'clarifications': clarifications.map((c) => c.toJson()).toList(),
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
    String? pdfUrl,
    double? confidenceScore,
    String? clarificationState,
    List<ClarificationModel>? clarifications,
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
      pdfUrl: pdfUrl ?? this.pdfUrl,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      clarificationState: clarificationState ?? this.clarificationState,
      clarifications: clarifications ?? this.clarifications,
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

  /// No report has been written yet: the questions are still out.
  ///
  /// The hospital has nothing in this state, which is the deliberate cost of
  /// asking first. It is also resumable — an app reopened here picks the
  /// sequence back up where it stopped.
  bool get isAwaitingClarification => generationStatus == 'awaiting_clarification';

  /// Questions still waiting on a tap. Empty once the record has been written:
  /// the answers were inputs to it, and there is nothing left to ask.
  List<ClarificationModel> get openClarifications => isAwaitingClarification
      ? clarifications.where((c) => !c.isAnswered && c.skippedAt == null).toList()
      : const [];

  bool get hasOpenClarifications => openClarifications.isNotEmpty;

  /// How many answers actually fed this report, for the line that says so.
  int get answeredClarificationCount =>
      clarifications.where((c) => c.isAnswered).length;
}
