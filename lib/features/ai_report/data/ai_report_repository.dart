import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/realtime/socket_service.dart';
import 'models/ai_report_model.dart';

class AIReportRepository {
  /// A reporter with no account holds only a case token, so every read here
  /// takes one optionally. Signed-in callers pass nothing and keep using their
  /// own token, exactly as before.
  Map<String, String>? _caseHeader(String? caseToken) =>
      (caseToken == null || caseToken.isEmpty) ? null : {'Authorization': 'Bearer $caseToken'};

  // POST /api/ai/report — multipart (voice + images + text). Uses the raw Dio
  // instance because we need form-data with files and long timeouts.
  Future<AIReportModel> generateReport({
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
      final report = AIReportModel.fromJson(data);
      // A 200 from this endpoint means the report finished. Older backends
      // omit generation_status, which would leave the model looking 'pending'
      // and hide the result screen the patient just waited for.
      if (!report.isComplete && (report.id != null || report.urgencyLevel != null)) {
        return report.copyWith(generationStatus: 'completed');
      }
      return report;
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
