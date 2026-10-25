import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sos/providers/session_provider.dart';
import '../data/ai_report_repository.dart';
import '../data/models/ai_report_model.dart';
import '../data/models/clarification_model.dart';
import '../data/models/recording_state_model.dart';

class AIReportState {
  final RecordingStatus recordingStatus;
  final Duration recordingDuration;
  final String? audioPath;
  final List<String> selectedImages;
  final String textInput;
  final String selectedLanguage; // 'auto' | 'en' | 'ur' | 'sd' | 'roman_ur'
  final bool isSubmitting;
  final AIReportModel? report;
  final String? error;

  /// The questions put before anything is written, while they are still open.
  ///
  /// Held here rather than on [report] because during this phase there is no
  /// report: the whole point of asking first is that nothing has been written
  /// and nothing has reached the hospital.
  final List<ClarificationModel> clarifications;

  /// True between the questions arriving and the record being written.
  final bool awaitingClarification;

  /// A single answer is in flight.
  final bool isAnswering;

  /// The answer that closed the sequence is in flight, so the record is being
  /// written right now. Separate from [isAnswering] because the wait is ten
  /// seconds rather than one and the screen has to say something different.
  final bool isFinalising;

  const AIReportState({
    this.recordingStatus = RecordingStatus.idle,
    this.recordingDuration = Duration.zero,
    this.audioPath,
    this.selectedImages = const [],
    this.textInput = '',
    this.selectedLanguage = 'auto',
    this.isSubmitting = false,
    this.report,
    this.error,
    this.clarifications = const [],
    this.awaitingClarification = false,
    this.isAnswering = false,
    this.isFinalising = false,
  });

  bool get hasAnyInput =>
      (audioPath != null && audioPath!.isNotEmpty) ||
      textInput.trim().isNotEmpty ||
      selectedImages.isNotEmpty;

  /// Questions still needing a tap.
  List<ClarificationModel> get openClarifications =>
      clarifications.where((c) => !c.isAnswered && c.skippedAt == null).toList();

  AIReportState copyWith({
    RecordingStatus? recordingStatus,
    Duration? recordingDuration,
    String? audioPath,
    List<String>? selectedImages,
    String? textInput,
    String? selectedLanguage,
    bool? isSubmitting,
    AIReportModel? report,
    String? error,
    List<ClarificationModel>? clarifications,
    bool? awaitingClarification,
    bool? isAnswering,
    bool? isFinalising,
    bool clearAudio = false,
    bool clearReport = false,
    bool clearError = false,
  }) {
    return AIReportState(
      recordingStatus: recordingStatus ?? this.recordingStatus,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      selectedImages: selectedImages ?? this.selectedImages,
      textInput: textInput ?? this.textInput,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      report: clearReport ? null : (report ?? this.report),
      error: clearError ? null : (error ?? this.error),
      clarifications: clarifications ?? this.clarifications,
      awaitingClarification: awaitingClarification ?? this.awaitingClarification,
      isAnswering: isAnswering ?? this.isAnswering,
      isFinalising: isFinalising ?? this.isFinalising,
    );
  }
}

class AIReportNotifier extends StateNotifier<AIReportState> {
  AIReportNotifier(this._repository, this._socketService, this._ref)
      : super(const AIReportState());

  final AIReportRepository _repository;
  final SocketService _socketService;
  final Ref _ref;

  /// A reporter with no account sends their case token instead of a login.
  String? _caseToken(String caseId) => caseTokenFor(
        _ref.read(sessionProvider),
        signedIn: _ref.read(authProvider).isAuthenticated,
        caseId: caseId,
      );
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _durationTimer;

  Future<void> startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        state = state.copyWith(error: 'Microphone permission denied');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/resqpk_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: path,
      );

      state = state.copyWith(
        recordingStatus: RecordingStatus.recording,
        audioPath: path,
        recordingDuration: Duration.zero,
        clearError: true,
      );

      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = state.copyWith(
          recordingDuration: state.recordingDuration + const Duration(seconds: 1),
        );
      });
    } catch (e) {
      state = state.copyWith(error: 'Could not start recording: $e');
    }
  }

  Future<void> stopRecording() async {
    _durationTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      state = state.copyWith(
        recordingStatus: RecordingStatus.recorded,
        audioPath: path ?? state.audioPath,
      );
    } catch (e) {
      state = state.copyWith(error: 'Could not stop recording: $e');
    }
  }

  Future<void> cancelRecording() async {
    _durationTimer?.cancel();
    try {
      await _audioRecorder.cancel();
    } catch (_) {/* ignore */}
    final path = state.audioPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {/* ignore */}
      }
    }
    state = state.copyWith(
      recordingStatus: RecordingStatus.idle,
      recordingDuration: Duration.zero,
      clearAudio: true,
    );
  }

  Future<void> pickImages() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 70);
      if (picked.isEmpty) return;
      final combined = [...state.selectedImages, ...picked.map((f) => f.path)];
      state = state.copyWith(selectedImages: combined.take(4).toList());
    } catch (e) {
      state = state.copyWith(error: 'Could not pick images: $e');
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= state.selectedImages.length) return;
    final list = [...state.selectedImages]..removeAt(index);
    state = state.copyWith(selectedImages: list);
  }

  /// The report flow takes one photo, not a gallery: a single clear picture of
  /// the patient is what the doctor reading this actually uses, and choosing
  /// four of them is not a job for someone standing over a casualty.
  void setPhoto(String path) => state = state.copyWith(selectedImages: [path]);

  void clearPhoto() => state = state.copyWith(selectedImages: const []);

  Future<void> pickPhotoFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked != null) setPhoto(picked.path);
    } catch (e) {
      state = state.copyWith(error: 'Could not open the gallery: $e');
    }
  }

  /// Takes a report fetched from the server into state without touching the
  /// recorded inputs. Used when a screen finds a finished report for a case
  /// that this notifier knows nothing about — after an app restart, or when
  /// the report was generated on another device on the same case.
  void adoptExistingReport(AIReportModel report) {
    if (state.report != null) return; // never overwrite a fresher local one
    state = state.copyWith(report: report);
  }

  /// Starts a new report, keeping nothing from the last one.
  void startFresh() {
    _durationTimer?.cancel();
    state = const AIReportState();
  }

  void setTextInput(String text) => state = state.copyWith(textInput: text);

  void setLanguage(String language) => state = state.copyWith(selectedLanguage: language);

  /// Phase one: send the inputs and get back the questions.
  ///
  /// Nothing reaches the hospital here. The server transcribes, looks at any
  /// photo, and composes the two to four questions it needs answered before it
  /// will write a clinical record. Returns true when there are questions to
  /// put, false when the record was written straight away because there were
  /// none worth asking.
  Future<bool> submitReport(String caseId) async {
    if (!state.hasAnyInput) {
      state = state.copyWith(error: 'Add a voice note, text, or photo first');
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      recordingStatus: RecordingStatus.processing,
      awaitingClarification: false,
      clarifications: const [],
      clearError: true,
      clearReport: true,
    );

    // Reflect live progress from the backend while we await the response.
    final caseToken = _caseToken(caseId);
    final sub =
        _repository.watchReportStatus(caseId, _socketService, caseToken: caseToken).listen((r) {
      if (r.isProcessing) {
        state = state.copyWith(recordingStatus: RecordingStatus.processing);
      }
    });

    try {
      final result = await _repository.startReport(
        caseId: caseId,
        audioFilePath: state.audioPath,
        textInput: state.textInput,
        imagePaths: state.selectedImages,
        language: state.selectedLanguage,
        caseToken: caseToken,
      );

      if (result.awaitingClarification) {
        state = state.copyWith(
          clarifications: result.clarifications,
          awaitingClarification: true,
          isSubmitting: false,
          recordingStatus: RecordingStatus.processing,
        );
        return true;
      }

      state = state.copyWith(
        report: result.report,
        clarifications: result.report?.clarifications ?? const [],
        awaitingClarification: false,
        recordingStatus: RecordingStatus.completed,
        isSubmitting: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        recordingStatus: RecordingStatus.error,
        isSubmitting: false,
        awaitingClarification: false,
      );
      return false;
    } finally {
      await sub.cancel();
    }
  }

  /// Picks the question sequence back up for a case this notifier knows nothing
  /// about — the app was killed part way through, or reopened from tracking.
  ///
  /// Returns true when there are still questions out.
  Future<bool> resumeClarification(String caseId) async {
    try {
      final open = await _repository.getOpenClarifications(
        caseId,
        caseToken: _caseToken(caseId),
      );
      final outstanding = open.where((c) => !c.isAnswered && c.skippedAt == null).toList();
      if (outstanding.isEmpty) return false;
      state = state.copyWith(clarifications: open, awaitingClarification: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Records one single-tap answer.
  ///
  /// Returns false when the answer did not land, so the screen can stay on the
  /// question rather than moving on and losing it. Nothing has been written or
  /// sent at this point, so a failed answer costs one field and no one at the
  /// hospital is reading anything yet.
  ///
  /// The answer that closes the sequence is the one that makes the server write
  /// the record and deliver it; that response carries the finished report, and
  /// [AIReportState.isFinalising] is true while it is in flight.
  Future<bool> answerClarification(
    String caseId, {
    required String questionId,
    required String answer,
  }) async {
    final last = state.openClarifications.length <= 1;
    state = state.copyWith(
      isAnswering: true,
      isFinalising: last,
      clearError: true,
    );
    try {
      final result = await _repository.answerClarification(
        caseId,
        questionId: questionId,
        answer: answer,
        caseToken: _caseToken(caseId),
      );
      state = state.copyWith(
        clarifications: result.clarifications.isEmpty
            ? state.clarifications
            : result.clarifications,
        report: result.report,
        awaitingClarification: result.report == null,
        recordingStatus:
            result.report != null ? RecordingStatus.completed : state.recordingStatus,
        isAnswering: false,
        isFinalising: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        isAnswering: false,
        isFinalising: false,
      );
      return false;
    }
  }

  /// Closes the sequence and has the record written from whatever is known.
  ///
  /// This is the deliberate skip, and it is what bounds the delay asking first
  /// imposes: one tap and the hospital has its report. Not fire-and-forget —
  /// the report does not exist until this returns, so the screen has to wait
  /// for it. Returns false if it failed, leaving the questions where they were.
  Future<bool> skipClarifications(String caseId) async {
    state = state.copyWith(isFinalising: true, clearError: true);
    try {
      final report = await _repository.skipClarifications(
        caseId,
        caseToken: _caseToken(caseId),
      );
      state = state.copyWith(
        report: report,
        awaitingClarification: false,
        recordingStatus: report != null ? RecordingStatus.completed : state.recordingStatus,
        isFinalising: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        isFinalising: false,
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void reset() {
    _durationTimer?.cancel();
    state = const AIReportState();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

final aiReportRepositoryProvider = Provider<AIReportRepository>((ref) => AIReportRepository());

final aiReportProvider = StateNotifierProvider<AIReportNotifier, AIReportState>((ref) {
  return AIReportNotifier(
    ref.read(aiReportRepositoryProvider),
    ref.read(socketServiceProvider),
    ref,
  );
});
