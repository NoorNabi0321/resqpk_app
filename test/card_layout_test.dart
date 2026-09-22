import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/theme/tokens.dart';
import 'package:resqpk_app/core/widgets/resq_card.dart';
import 'package:resqpk_app/features/driver/widgets/driver_chrome.dart';

/// Cards must survive an unbounded height.
///
/// Both cards used to draw their accent stripe as a Row child with
/// CrossAxisAlignment.stretch, which asks every child to fill the cross axis.
/// Inside a ListView or a scrolling Column that is infinite, the assertion
/// takes the card out of the layout, and a release build paints a failed
/// widget as an empty box — so the card silently disappears rather than
/// complaining. It emptied the driver dashboard, and the patient's tracking
/// card the moment a hospital was confirmed.
///
/// Every one of these pumps an accented card in a scrolling parent. They fail
/// if that ever comes back.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(backgroundColor: Resq.canvas, body: child),
      );

  final content = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Civil Hospital Hyderabad'),
      const SizedBox(height: 4),
      const Text('Waiting for the hospital to accept'),
    ],
  );

  group('ResqCard', () {
    testWidgets('accented, inside a ListView', (tester) async {
      await tester.pumpWidget(host(ListView(
        children: [ResqCard(accent: Resq.ready, child: content)],
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('Civil Hospital Hyderabad'), findsOneWidget);
    });

    testWidgets('accented, inside a scrolling Column — the tracking card', (tester) async {
      await tester.pumpWidget(host(SingleChildScrollView(
        child: Column(
          children: [ResqCard(accent: Resq.decision, child: content)],
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('Civil Hospital Hyderabad'), findsOneWidget);
    });

    testWidgets('without an accent', (tester) async {
      await tester.pumpWidget(host(ListView(children: [ResqCard(child: content)])));
      expect(tester.takeException(), isNull);
    });
  });

  group('DriverCard', () {
    testWidgets('accented, inside a ListView — the duty screen', (tester) async {
      await tester.pumpWidget(host(ListView(
        children: [DriverCard(accent: Resq.ready, child: content)],
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('Civil Hospital Hyderabad'), findsOneWidget);
    });

    testWidgets('StatTile row, three across a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(ListView(
        children: const [
          Row(
            children: [
              Expanded(child: StatTile(value: '3', label: 'Runs today', color: Resq.ready)),
              SizedBox(width: Resq.space3),
              Expanded(child: StatTile(value: '41', label: 'Completed', color: Resq.info)),
              SizedBox(width: Resq.space3),
              Expanded(
                child: StatTile(value: '92%', label: 'Offers accepted', color: Resq.decision),
              ),
            ],
          ),
        ],
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('92%'), findsOneWidget);
    });
  });
}
