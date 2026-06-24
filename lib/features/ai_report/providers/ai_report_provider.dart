import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/realtime/realtime_provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../data/ai_report_repository.dart';
import '../data/models/ai_report_model.dart';
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
  });

  bool get hasAnyInput =>
      (audioPath != null && audioPath!.isNotEmpty) ||
      textInput.trim().isNotEmpty ||
      selectedImages.isNotEmpty;

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
    );
  }
}

class AIReportNotifier extends StateNotifier<AIReportState> {
  AIReportNotifier(this._repository, this._socketService) : super(const AIReportState());

  final AIReportRepository _repository;
  final SocketService _socketService;
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

  void setTextInput(String text) => state = state.copyWith(textInput: text);

  void setLanguage(String language) => state = state.copyWith(selectedLanguage: language);

  Future<void> submitReport(String caseId) async {
    if (!state.hasAnyInput) {
      state = state.copyWith(error: 'Add a voice note, text, or photo first');
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      recordingStatus: RecordingStatus.processing,
      clearError: true,
      clearReport: true,
    );

    // Reflect live progress from the backend while we await the response.
    final sub = _repository.watchReportStatus(caseId, _socketService).listen((r) {
      if (r.isProcessing) {
        state = state.copyWith(recordingStatus: RecordingStatus.processing);
      }
    });

    try {
      final report = await _repository.generateReport(
        caseId: caseId,
        audioFilePath: state.audioPath,
        textInput: state.textInput,
        imagePaths: state.selectedImages,
        language: state.selectedLanguage,
      );
      state = state.copyWith(
        report: report,
        recordingStatus: RecordingStatus.completed,
        isSubmitting: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        recordingStatus: RecordingStatus.error,
        isSubmitting: false,
      );
    } finally {
      await sub.cancel();
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
  );
});
