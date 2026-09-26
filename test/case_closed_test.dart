import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:resqpk_app/core/router/app_router.dart';
import 'package:resqpk_app/features/driver/screens/case_closed_screen.dart';

/// The screen that explains why the driver's map went away.
///
/// It has one job beyond saying so: leave on its own. A driver who puts the
/// phone down mid-sentence must not come back to a dead end, and a screen that
/// waits for a tap is exactly that.
void main() {
  Future<void> pump(WidgetTester tester, {String? reason}) async {
    final router = GoRouter(
      initialLocation: Routes.driverCaseClosed,
      routes: [
        GoRoute(
          path: Routes.driverCaseClosed,
          builder: (_, __) => CaseClosedScreen(reason: reason),
        ),
        GoRoute(
          path: Routes.driverHome,
          builder: (_, __) => const Scaffold(body: Text('DUTY SCREEN')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      tester.takeException();
    }
  }

  testWidgets('says what happened and thanks the driver', (tester) async {
    await pump(tester);

    expect(find.text('The patient cancelled'), findsOneWidget);
    expect(find.textContaining('thank you for answering'), findsOneWidget);
    expect(find.text('You are back on duty'), findsOneWidget);
    expect(find.text('DUTY SCREEN'), findsNothing);
  });

  testWidgets('a false alarm is named as one', (tester) async {
    await pump(tester, reason: 'false_alarm');
    expect(find.textContaining('false alarm'), findsOneWidget);
  });

  testWidgets('leaves for the duty screen on its own', (tester) async {
    await pump(tester);
    expect(find.text('DUTY SCREEN'), findsNothing);

    // Just before the hold is up it is still here.
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('DUTY SCREEN'), findsNothing,
        reason: 'it left early — the driver would not have finished reading');

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('DUTY SCREEN'), findsOneWidget,
        reason: 'it never left — the driver is stranded on an explanation');
  });

  testWidgets('a tap skips the wait', (tester) async {
    await pump(tester);

    await tester.tap(find.text('The patient cancelled'));
    await tester.pumpAndSettle();

    expect(find.text('DUTY SCREEN'), findsOneWidget);
  });

  testWidgets('leaving early does not fire the timer into a dead context',
      (tester) async {
    // The timer outlives a tap unless it is cancelled, and firing it after the
    // route is gone throws on a disposed context.
    await pump(tester);
    await tester.tap(find.text('The patient cancelled'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
