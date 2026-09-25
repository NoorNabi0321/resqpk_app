import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/theme/tokens.dart';
import 'package:resqpk_app/core/widgets/step_slider.dart';

/// The instruction panel must not resize between steps.
///
/// It used to grow and shrink with the length of each instruction, which moved
/// the arrows under the reader's thumb and re-laid-out the illustration on
/// every swipe.
void main() {
  // Instructions that differ wildly in length — one word against a paragraph
  // is the case that used to make the panel jump.
  const steps = [
    StepSliderItem(number: 1, title: 'Check', instruction: 'Shout.'),
    StepSliderItem(
      number: 2,
      title: 'Compressions',
      instruction: 'Put the heel of one hand in the centre of the chest and the '
          'other hand on top. Press down hard and fast, about twice a second, '
          'letting the chest come all the way back up between pushes. Keep '
          'going until help arrives or the person starts breathing.',
    ),
    StepSliderItem(
      number: 3,
      title: 'Call',
      instruction: 'Call 1122 and say where you are.',
    ),
  ];

  /// Height of the navy panel as it currently stands.
  double panelHeight(WidgetTester tester) {
    final panel = find.byWidgetPredicate(
      (w) => w is Container && w.decoration is BoxDecoration
          ? (w.decoration! as BoxDecoration).color == Resq.navy
          : false,
    );
    expect(panel, findsOneWidget);
    return tester.getSize(panel).height;
  }

  Future<void> pumpSlider(WidgetTester tester, {bool rtl = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepSlider(steps: steps, rtl: rtl),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(320, 640), const Size(411, 891)]) {
    testWidgets('panel keeps one height across every step at ${size.width}dp',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpSlider(tester);
      final first = panelHeight(tester);

      for (var i = 1; i < steps.length; i++) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(
          panelHeight(tester),
          first,
          reason: 'step ${i + 1} resized the panel',
        );
      }
    });
  }

  testWidgets('the panel is tall enough for the longest instruction',
      (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSlider(tester);

    // Swipe to the long step and check nothing overflowed onto the paint layer.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Press down hard and fast'), findsOneWidget);
  });

  testWidgets('Urdu steps get their own consistent height', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSlider(tester, rtl: true);
    final first = panelHeight(tester);

    // RTL: the next page is to the right.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(panelHeight(tester), first);
  });
}
