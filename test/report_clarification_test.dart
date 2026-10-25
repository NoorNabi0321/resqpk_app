import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/features/ai_report/data/models/ai_report_model.dart';
import 'package:resqpk_app/features/ai_report/data/models/clarification_model.dart';

/// The questions are asked before the record is written, so "is a question
/// still open" decides whether the hospital has anything at all. Getting it
/// wrong in either direction is bad: a case parked forever with the ward
/// waiting, or a screen of taps shown over a report that is already sent.
void main() {
  Map<String, dynamic> q(
    String id, {
    String? answer,
    String? skippedAt,
    List<String> options = const ['Yes', 'No'],
    String question = 'Is the patient awake?',
  }) =>
      {
        'id': id,
        'field': 'consciousness_state',
        'question': question,
        'options': options,
        'answer': answer,
        'skipped_at': skippedAt,
      };

  /// A case parked on the questions: analysed, nothing written, nothing sent.
  AIReportModel awaiting(List<Map<String, dynamic>> questions) => AIReportModel.fromJson({
        'case_id': 'case-1',
        'generation_status': 'awaiting_clarification',
        'clarification_state': 'awaiting',
        'clarifications': questions,
      });

  /// A finished record, written from those questions.
  AIReportModel written(
    List<Map<String, dynamic>> questions, {
    String state = 'answered',
  }) =>
      AIReportModel.fromJson({
        'case_id': 'case-1',
        'generation_status': 'completed',
        'clarification_state': state,
        'clarifications': questions,
      });

  group('ClarificationModel.listFrom', () {
    test('keeps well-formed questions', () {
      final list = ClarificationModel.listFrom([q('q1'), q('q2')]);
      expect(list.map((c) => c.id), ['q1', 'q2']);
      expect(list.first.options, ['Yes', 'No']);
    });

    test('drops a question with fewer than two options — it is not a choice', () {
      expect(ClarificationModel.listFrom([q('q1', options: ['Yes'])]), isEmpty);
    });

    test('drops a question with no id or no text to ask', () {
      expect(ClarificationModel.listFrom([q('')]), isEmpty);
      expect(ClarificationModel.listFrom([q('q1', question: '')]), isEmpty);
    });

    test('is empty for anything that is not a list', () {
      expect(ClarificationModel.listFrom(null), isEmpty);
      expect(ClarificationModel.listFrom('two questions'), isEmpty);
    });

    test('reads an answer, and treats an empty string as unanswered', () {
      final answered = ClarificationModel.listFrom([q('q1', answer: 'Yes')]).single;
      expect(answered.isAnswered, isTrue);
      expect(answered.answer, 'Yes');

      final blank = ClarificationModel.listFrom([q('q1', answer: '')]).single;
      expect(blank.isAnswered, isFalse);
      expect(blank.answer, isNull);
    });
  });

  group('the language a question is read in', () {
    Map<String, dynamic> bilingual({
      List<String> options = const ['Awake', 'Drowsy', 'Not responding'],
      dynamic optionsLocal = const ['ہوش میں', 'غنودگی', 'جواب نہیں دے رہا'],
      dynamic questionLocal = 'مریض ہوش میں ہے؟',
    }) =>
        {
          'id': 'q1',
          'field': 'consciousness_state',
          'question': 'Is the patient awake?',
          'options': options,
          'question_local': questionLocal,
          'options_local': optionsLocal,
        };

    test('shows the local text, records the English', () {
      final q = ClarificationModel.listFrom([bilingual()]).single;
      expect(q.displayQuestion(), 'مریض ہوش میں ہے؟');
      expect(q.displayOptions(), ['ہوش میں', 'غنودگی', 'جواب نہیں دے رہا']);
      // The tap is resolved by position: tapping the Urdu "جواب نہیں دے رہا"
      // must record the English "Not responding", never the Urdu.
      expect(q.answerFor(2), 'Not responding');
      expect(q.answerFor(0), 'Awake');
    });

    test('falls back to English when there is no translation', () {
      final q = ClarificationModel.listFrom([
        bilingual(questionLocal: null, optionsLocal: null),
      ]).single;
      expect(q.displayQuestion(), 'Is the patient awake?');
      expect(q.displayOptions(), ['Awake', 'Drowsy', 'Not responding']);
      expect(q.answerFor(1), 'Drowsy');
    });

    test('rejects a local list of the wrong length outright', () {
      // This is the dangerous case: a shorter local list would put the tapped
      // position against the wrong English option. Half a translation is worse
      // than none, so the whole thing is discarded.
      final q = ClarificationModel.listFrom([
        bilingual(optionsLocal: const ['ہوش میں', 'غنودگی']),
      ]).single;
      expect(q.questionLocal, isNull);
      expect(q.optionsLocal, isNull);
      expect(q.displayOptions(), ['Awake', 'Drowsy', 'Not responding']);
    });

    test('rejects local options with no local question', () {
      final q = ClarificationModel.listFrom([bilingual(questionLocal: null)]).single;
      expect(q.displayQuestion(), 'Is the patient awake?');
      expect(q.optionsLocal, isNull);
    });

    test('answerFor is in range or empty, never out of bounds', () {
      final q = ClarificationModel.listFrom([bilingual()]).single;
      expect(q.answerFor(-1), '');
      expect(q.answerFor(99), '');
    });

    test('the translation survives a round trip', () {
      final q = ClarificationModel.listFrom([bilingual()]).single;
      final again = ClarificationModel.fromJson(q.toJson());
      expect(again.displayQuestion(), 'مریض ہوش میں ہے؟');
      expect(again.answerFor(2), 'Not responding');
    });
  });

  group('while the questions are out', () {
    test('a parked case has no report and every question open', () {
      final r = awaiting([q('q1'), q('q2')]);
      expect(r.isAwaitingClarification, isTrue);
      expect(r.isComplete, isFalse);
      expect(r.openClarifications.length, 2);
    });

    test('an answered question is not asked again', () {
      final r = awaiting([q('q1', answer: 'Yes'), q('q2')]);
      expect(r.openClarifications.map((c) => c.id), ['q2']);
    });

    test('a skipped question is not asked again', () {
      final r = awaiting([q('q1', skippedAt: '2026-10-25T10:00:00Z'), q('q2')]);
      expect(r.openClarifications.map((c) => c.id), ['q2']);
    });
  });

  group('once the record is written', () {
    test('nothing is open, even though the questions are still on the row', () {
      final r = written([q('q1', answer: 'Yes'), q('q2', answer: 'No')]);
      expect(r.isAwaitingClarification, isFalse);
      expect(r.hasOpenClarifications, isFalse);
      expect(r.answeredClarificationCount, 2);
    });

    test('a skipped sequence asks nothing after the fact', () {
      // This is the case that would have reopened the questions under the old
      // progressive model. The report exists and is with the hospital; the
      // unanswered questions are history, not a to-do list.
      final r = written(
        [q('q1', answer: 'Yes'), q('q2', skippedAt: '2026-10-25T10:00:00Z')],
        state: 'skipped',
      );
      expect(r.hasOpenClarifications, isFalse);
      expect(r.answeredClarificationCount, 1);
      expect(r.clarifications.length, 2);
    });

    test('a report nobody was asked about counts no answers', () {
      final r = written(const [], state: 'none');
      expect(r.hasOpenClarifications, isFalse);
      expect(r.answeredClarificationCount, 0);
    });

    test('an older report, from before the questions existed, reads as none', () {
      final r = AIReportModel.fromJson({
        'case_id': 'case-1',
        'generation_status': 'completed',
      });
      expect(r.clarificationState, 'none');
      expect(r.isAwaitingClarification, isFalse);
      expect(r.hasOpenClarifications, isFalse);
      expect(r.confidenceScore, isNull);
    });
  });

  group('the shapes the server actually sends', () {
    test('the finished report, which is camelCase', () {
      final r = AIReportModel.fromJson({
        'caseId': 'case-1',
        'generationStatus': 'completed',
        'clarificationState': 'answered',
        'confidenceScore': 0.62,
        'clarifications': [q('q1', answer: 'Yes')],
      });
      expect(r.isComplete, isTrue);
      expect(r.confidenceScore, 0.62);
      expect(r.answeredClarificationCount, 1);
      expect(r.hasOpenClarifications, isFalse);
    });

    test('a database row, which is snake_case', () {
      final r = AIReportModel.fromJson({
        'case_id': 'case-1',
        'generation_status': 'awaiting_clarification',
        'clarification_state': 'awaiting',
        'confidence_score': '0.4',
        'clarifications': [q('q1', answer: 'Yes'), q('q2')],
      });
      expect(r.confidenceScore, 0.4);
      expect(r.openClarifications.single.id, 'q2');
    });

    test('the questions survive a round trip through local storage', () {
      final r = awaiting([q('q1', answer: 'Yes'), q('q2')]);
      final again = AIReportModel.fromJson(r.toJson());
      expect(again.clarificationState, 'awaiting');
      expect(again.openClarifications.single.id, 'q2');
    });
  });
}
