import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/realtime/socket_service.dart';
import 'models/ai_report_model.dart';
import 'models/clarification_model.dart';

/// What came back from starting a report.
///
/// Two outcomes, and the caller has to handle both: either there are questions
/// to put before anything is written, or there were none worth asking and the
/// finished report is already here.
class ReportStartResult {
  const ReportStartResult({
    required this.awaitingClarification,
    this.clarifications = const [],
    this.report,
    this.transcribedText,
  });

  final bool awaitingClarification;
  final List<ClarificationModel> clarifications;

  /// Only set when no questions were asked — then this is the final report.
  final AIReportModel? report;

  /// What the voice note turned out to say. Shown on the questions screen so
  /// someone can see their own words were heard before being asked more.
  final String? transcribedText;
}

/// The sequence is over and a report already exists.
///
/// Thrown when the server answers 409: the deadline closed the questions, or
/// another tap got there first. Not an error the person caused and not one they
/// can do anything about — the report they were working towards exists, so the
/// only sensible response is to show it to them.
class ClarificationClosedException implements Exception {
  const ClarificationClosedException();
  @override
  String toString() => 'The report has already been written';
}

/// What came back from answering one question.
class ClarificationAnswerResult {
  const ClarificationAnswerResult({
    required this.clarifications,
    required this.remaining,
    this.report,
  });

  final List<ClarificationModel> clarifications;
  final int remaining;

  /// Set only on the answer that closed the sequence: the record is written
  /// and the hospital has it.
  final AIReportModel? report;
}

class AIReportRepository {
  /// A reporter with no account holds only a case token, so every read here
  /// takes one optionally. Signed-in callers pass nothing and keep using their
  /// own token, exactly as before.
  Map<String, String>? _caseHeader(String? caseToken) =>
      (caseToken == null || caseToken.isEmpty) ? null : {'Authorization': 'Bearer $caseToken'};

  /// POST /api/ai/report — multipart (voice + images + text).
  ///
  /// Starts the report; it does not finish one. The server analyses the inputs
  /// and comes back with the questions to put before anything is written, so
  /// nothing has reached the hospital when this returns. Uses the raw Dio
  /// instance because we need form-data with files and long timeouts.
  Future<ReportStartResult> startReport({
    required String caseId,
    String? audioFilePath,
    String? textInput,
    List<String> imagePaths = const [],
    String language = 'auto',
    String? caseToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        'case_id': caseId,
        if (textInput != null && textInput.isNotEmpty) 'text': textInput,
        'language': language,
      });

      if (audioFilePath != null && audioFilePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'voice_note',
            await MultipartFile.fromFile(
              audioFilePath,
              filename: 'voice_note.m4a',
              contentType: DioMediaType('audio', 'm4a'),
            ),
          ),
        );
      }

      for (var i = 0; i < imagePaths.length; i++) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              imagePaths[i],
              filename: 'image_$i.jpg',
              contentType: DioMediaType('image', 'jpeg'),
            ),
          ),
        );
      }

      final res = await apiClient.dio.post(
        '/api/ai/report',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 120),
          headers: _caseHeader(caseToken),
          // Only a case-scoped call gets the flag; otherwise a genuine 401
          // would stop clearing the signed-in user's expired token.
          extra: _caseHeader(caseToken) == null ? null : const {'caseScoped': true},
        ),
      );

      final data = (res.data is Map && res.data['data'] != null)
          ? res.data['data'] as Map<String, dynamic>
          : res.data as Map<String, dynamic>;

      if (data['generationStatus']?.toString() == 'awaiting_clarification') {
        return ReportStartResult(
          awaitingClarification: true,
          clarifications: ClarificationModel.listFrom(data['clarifications']),
          transcribedText: data['transcribedText']?.toString(),
        );
      }

      // No questions were worth asking, so this is the finished report.
      final report = AIReportModel.fromJson(data);
      // A 200 here with report fields means generation finished. Older
      // backends omit generation_status, which would leave the model looking
      // 'pending' and hide the result screen the patient just waited for.
      final settled = !report.isComplete && (report.id != null || report.urgencyLevel != null)
          ? report.copyWith(generationStatus: 'completed')
          : report;
      return ReportStartResult(
        awaitingClarification: false,
        report: settled,
        transcribedText: settled.transcribedText,
      );
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // GET /api/ai/report/:caseId — returns the report or null if not found.
  Future<AIReportModel?> getReport(String caseId, {String? caseToken}) async {
    try {
      final res = await apiClient.get('/api/ai/report/$caseId', caseToken: caseToken);
      final data = res['data'];
      if (data is! Map<String, dynamic>) return null;
      return AIReportModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(_err(e));
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  /// GET /api/ai/report/:caseId/pdf — a freshly signed URL. Stored URLs expire
  /// after ~6 hours, so always mint a new one before opening the document.
  Future<String?> getReportPdfUrl(String caseId, {String? caseToken}) async {
    try {
      final res = await apiClient.get('/api/ai/report/$caseId/pdf', caseToken: caseToken);
      final data = res['data'];
      if (data is Map) return data['pdfUrl']?.toString();
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(_err(e));
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  /// GET /api/ai/report/:caseId/clarify — the questions still open.
  ///
  /// For resuming a sequence the app was part way through. Returns just the
  /// questions rather than the whole report row, which carries the raw model
  /// response and is far too heavy for this.
  Future<List<ClarificationModel>> getOpenClarifications(
    String caseId, {
    String? caseToken,
  }) async {
    try {
      final res = await apiClient.get(
        '/api/ai/report/$caseId/clarify',
        caseToken: caseToken,
      );
      final data = res['data'];
      if (data is! Map) return const [];
      return ClarificationModel.listFrom(data['clarifications']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      throw Exception(_err(e));
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  /// POST /api/ai/report/:caseId/clarify — one single-tap answer.
  ///
  /// The answers are inputs to the report, not edits to one: nothing has been
  /// written or sent yet. The answer that closes the sequence is the one that
  /// makes the server write the record and deliver it, and that response
  /// carries the finished report — which is why this call needs a long timeout.
  Future<ClarificationAnswerResult> answerClarification(
    String caseId, {
    required String questionId,
    required String answer,
    String? caseToken,
  }) async {
    try {
      final res = await apiClient.dio.post(
        '/api/ai/report/$caseId/clarify',
        data: {'questionId': questionId, 'answer': answer},
        options: Options(
          // The last answer generates the record and renders the PDF before
          // responding. The default 30s would time out on exactly the request
          // that matters most.
          receiveTimeout: const Duration(seconds: 120),
          headers: _caseHeader(caseToken),
          extra: _caseHeader(caseToken) == null ? null : const {'caseScoped': true},
        ),
      );
      return _answerResult(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) throw const ClarificationClosedException();
      throw Exception(_err(e));
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  /// POST /api/ai/report/:caseId/clarify/skip — stop asking, write the report.
  ///
  /// The deliberate skip. Whatever was answered still feeds the record; the
  /// rest stays unreported. Returns the finished report.
  Future<AIReportModel?> skipClarifications(String caseId, {String? caseToken}) async {
    try {
      final res = await apiClient.dio.post(
        '/api/ai/report/$caseId/clarify/skip',
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          headers: _caseHeader(caseToken),
          extra: _caseHeader(caseToken) == null ? null : const {'caseScoped': true},
        ),
      );
      return _answerResult(res.data).report;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) throw const ClarificationClosedException();
      throw Exception(_err(e));
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  ClarificationAnswerResult _answerResult(dynamic body) {
    final data = (body is Map && body['data'] is Map)
        ? Map<String, dynamic>.from(body['data'] as Map)
        : (body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{});

    final reportJson = data['report'];
    return ClarificationAnswerResult(
      clarifications: ClarificationModel.listFrom(data['clarifications']),
      remaining: int.tryParse('${data['remaining']}') ?? 0,
      report: reportJson is Map
          ? AIReportModel.fromJson(Map<String, dynamic>.from(reportJson))
          : null,
    );
  }

  /// POST /api/ai/report/:caseId/send — push the report at the hospital again.
  ///
  /// The pipeline sends it automatically the moment it is ready, so this is for
  /// the case where staff say they cannot see it: one tap, and it lands in the
  /// dashboard again rather than being re-dictated over a phone.
  Future<void> sendReportToHospital(String caseId, {String? caseToken}) async {
    try {
      await apiClient.post('/api/ai/report/$caseId/send', caseToken: caseToken);
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  /// Downloads the PDF to a local file so it can be rendered, shared, or saved.
  ///
  /// Uses a bare Dio client on purpose: the shared apiClient has an interceptor
  /// that stamps our bearer token onto every request, and the signed URL points
  /// at Supabase Storage, which rejects an Authorization header it cannot parse.
  Future<File> downloadPdf(String url, String filePath) async {
    try {
      final res = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final bytes = res.data ?? <int>[];
      if (bytes.isEmpty) throw Exception('The downloaded report was empty');
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      throw Exception(_err(e));
    }
  }

  // Emits report updates as they arrive over the socket for this case.
  Stream<AIReportModel> watchReportStatus(
    String caseId,
    SocketService socketService, {
    String? caseToken,
  }) async* {
    await for (final evt in socketService.aiReportStream) {
      final evtCaseId = (evt['caseId'] ?? evt['case_id'])?.toString();
      if (evtCaseId != null && evtCaseId != caseId) continue;

      switch (evt['event']) {
        case 'processing':
          yield AIReportModel(caseId: caseId, generationStatus: 'processing');
          break;
        case 'report_ready':
          final full = await getReport(caseId, caseToken: caseToken);
          if (full != null) {
            yield full.copyWith(generationStatus: 'completed');
          } else {
            yield AIReportModel.fromJson({...evt, 'generation_status': 'completed'});
          }
          break;
        case 'error':
          yield AIReportModel(
            caseId: caseId,
            generationStatus: 'failed',
            errorMessage: evt['error']?.toString(),
          );
          break;
      }
    }
  }

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return e.message ?? 'Network error';
    }
    return e.toString();
  }
}
