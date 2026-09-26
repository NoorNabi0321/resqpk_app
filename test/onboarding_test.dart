import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/theme/tokens.dart';
import 'package:resqpk_app/features/auth/screens/onboarding_screen.dart';

/// Onboarding is the first thing anyone sees, and it sets a 34px headline over
/// a fixed-height button stack — the shape that runs out of room on a short
/// phone. The artwork cannot load in a test, so these check the scrim layer
/// and the controls, which is where the layout risk actually is.
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
    }
  }

  for (final size in [const Size(320, 640), const Size(411, 891)]) {
    testWidgets('the slide lays out at ${size.width.toInt()}dp', (tester) async {
      await pump(tester, size);

      expect(find.text('Next'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The button must span the screen. The column aligns to start and so
      // hands out loose constraints; without an explicit width the Stack
      // inside collapses to the width of the label, leaving a small button
      // pinned to the left edge that still looks deliberate in a screenshot.
      const gutter = Resq.space6;
      final button = tester.getRect(find.byType(InkWell));
      expect(button.left, gutter);
      expect(button.right, size.width - gutter);
      expect(button.height, 60);

      // And the label sits in the middle of it, not in the middle of the
      // space left over beside the arrow.
      final label = tester.getRect(find.text('Next'));
      expect((label.center.dx - button.center.dx).abs(), lessThan(1.0));
    });
  }

  testWidgets('every headline keeps its highlighted word', (tester) async {
    await pump(tester, const Size(411, 891));

    // The highlight is carried beside the headline rather than marked up in
    // it, so a reworded headline can leave the emphasis pointing at text that
    // is no longer there. The screen asserts in debug; this is what catches it.
    for (var page = 0; page < 3; page++) {
      final rich = tester.widgetList<Text>(find.byType(Text))
          .where((t) => t.textSpan != null)
          .toList();
      expect(rich, isNotEmpty, reason: 'page $page has no rich headline');

      final coloured = <String>[];
      for (final t in rich) {
        t.textSpan!.visitChildren((span) {
          if (span is TextSpan && span.style?.color == Resq.brandOnDark) {
            coloured.add(span.text ?? '');
          }
          return true;
        });
      }
      expect(coloured, isNotEmpty,
          reason: 'page $page lost its highlight — the word is not in the headline');
      expect(coloured.first.trim(), isNotEmpty);

      if (page < 2) {
        await tester.tap(find.text('Next'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          tester.takeException();
        }
      }
    }
  });

  testWidgets('the last page offers to finish, not to continue', (tester) async {
    await pump(tester, const Size(411, 891));

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      for (var j = 0; j < 6; j++) {
        await tester.pump(const Duration(milliseconds: 100));
        tester.takeException();
      }
    }

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });
}
