/// One refinement question and the answer, if it was given.
///
/// These arrive with the finished report rather than being asked before it:
/// the hospital already has the first-pass record, and every answer only makes
/// the copy in front of them better. Which is also why a question nobody
/// answers is not a failure — it is a field that stays as the model left it.
class ClarificationModel {
  const ClarificationModel({
    required this.id,
    required this.question,
    required this.options,
    this.field = 'key_observations',
    this.questionLocal,
    this.optionsLocal,
    this.answer,
    this.answeredAt,
    this.skippedAt,
  });

  final String id;

  /// The report field this answer refines. Decided by the server; carried here
  /// only so a screen can say what a question is about.
  final String field;

  final String question;

  /// Two to four of them, each a single tap. There is no text entry: someone
  /// standing over a casualty is not going to type.
  ///
  /// Always English — this is what the record and the hospital carry.
  final List<String> options;

  /// The same question in the language the reporter is writing in, or null when
  /// the model could not produce a complete translation.
  ///
  /// Display only. The answer sent to the server is always the English option
  /// at the tapped position, so nothing downstream has to match a translated
  /// string back to a canonical one.
  final String? questionLocal;
  final List<String>? optionsLocal;

  final String? answer;
  final DateTime? answeredAt;
  final DateTime? skippedAt;

  bool get isAnswered => answer != null && answer!.isNotEmpty;

  static List<String> _options(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  /// Only kept when it lines up option for option with the English list: the
  /// answer is chosen by position, and a list of a different length would mean
  /// tapping one option and recording another.
  static List<String>? _localOptions(dynamic v, int expected) {
    if (v == null) return null;
    final list = _options(v);
    return list.length == expected ? list : null;
  }

  factory ClarificationModel.fromJson(Map<String, dynamic> json) {
    final options = _options(json['options']);
    final local = _localOptions(json['options_local'] ?? json['optionsLocal'], options.length);
    final questionLocal = (json['question_local'] ?? json['questionLocal'])?.toString();
    final hasLocal = local != null && (questionLocal?.isNotEmpty ?? false);

    return ClarificationModel(
      id: json['id']?.toString() ?? '',
      field: json['field']?.toString() ?? 'key_observations',
      question: json['question']?.toString() ?? '',
      options: options,
      questionLocal: hasLocal ? questionLocal : null,
      optionsLocal: hasLocal ? local : null,
      answer: (json['answer']?.toString().isEmpty ?? true)
          ? null
          : json['answer'].toString(),
      answeredAt: _date(json['answered_at'] ?? json['answeredAt']),
      skippedAt: _date(json['skipped_at'] ?? json['skippedAt']),
    );
  }

  /// What to put on screen, and what to send back for the tap at [index].
  String displayQuestion() => questionLocal ?? question;
  List<String> displayOptions() => optionsLocal ?? options;

  /// The English option at a tapped position. Always what goes to the server.
  String answerFor(int index) =>
      index >= 0 && index < options.length ? options[index] : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'field': field,
        'question': question,
        'options': options,
        'question_local': questionLocal,
        'options_local': optionsLocal,
        'answer': answer,
        'answered_at': answeredAt?.toIso8601String(),
        'skipped_at': skippedAt?.toIso8601String(),
      };

  /// Only well-formed questions survive this: an id, something to ask, and at
  /// least two things to tap. A malformed one would render as a dead screen.
  bool get isUsable => id.isNotEmpty && question.isNotEmpty && options.length >= 2;

  static List<ClarificationModel> listFrom(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => ClarificationModel.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.isUsable)
        .toList();
  }
}
