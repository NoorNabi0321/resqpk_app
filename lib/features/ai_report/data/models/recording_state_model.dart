enum RecordingStatus {
  idle,
  recording,
  recorded,
  transcribing,
  processing,
  completed,
  error,
}

/// UI state for the voice-note recorder + AI report generation flow.
class RecordingState {
  final RecordingStatus status;
  final Duration recordingDuration;
  final String? audioFilePath;
  final String? transcribedText;
  final String? detectedLanguage;
  final bool isUploading;
  final String? error;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.recordingDuration = Duration.zero,
    this.audioFilePath,
    this.transcribedText,
    this.detectedLanguage,
    this.isUploading = false,
    this.error,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    Duration? recordingDuration,
    String? audioFilePath,
    String? transcribedText,
    String? detectedLanguage,
    bool? isUploading,
    String? error,
    bool clearError = false,
    bool clearAudio = false,
  }) {
    return RecordingState(
      status: status ?? this.status,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      audioFilePath: clearAudio ? null : (audioFilePath ?? this.audioFilePath),
      transcribedText: transcribedText ?? this.transcribedText,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
