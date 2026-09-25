import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/features/more/screens/more_screen.dart';

/// The More tab is where the emergency numbers live.
///
/// Three buttons across a narrow phone is the shape that overflows, and the
/// thing they do — open the dialer — fails silently on a real device if the
/// manifest has not declared the intent. Neither shows up anywhere else.
void main() {
  Future<void> pumpMore(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MoreScreen()),
        ),
      ),
    );
    // The fonts are fetched at runtime and cannot be in a test; clearing those
    // exceptions leaves any real layout error to be caught below.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
    }
  }

  for (final size in [const Size(320, 640), const Size(360, 780), const Size(411, 891)]) {
    testWidgets('the three emergency numbers fit at ${size.width.toInt()}dp',
        (tester) async {
      await pumpMore(tester, size);

      for (final number in ['1122', '115', '1020']) {
        expect(find.text(number), findsOneWidget, reason: '$number is missing');
      }
      for (final service in ['Rescue', 'Edhi', 'Chhipa']) {
        expect(find.text(service), findsOneWidget);
      }

      // A RenderFlex overflow paints a stripe and reports through the binding
      // rather than throwing, so it has to be asked for.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the sign-in tile does not claim to be the driver door',
      (tester) async {
    await pumpMore(tester, const Size(411, 891));

    // It opens the login screen, which has both tabs. Labelling it "I am a
    // driver" sent patients looking for a different entrance that is not there.
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('I am a driver'), findsNothing);
  });

  test('the manifest lets us reach the dialer', () {
    // Package visibility on Android 11+ hides the dialer unless it is queried
    // for. Without this, canLaunchUrl('tel:1122') answers false and every call
    // button in the app quietly does nothing — 1122, the hospitals, the camps,
    // and the driver and patient calling each other during a dispatch. It
    // cannot fail in a widget test and it cannot fail on an emulator image
    // with a dialer; it fails on the phones people actually carry.
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final queries = manifest.substring(
      manifest.indexOf('<queries>'),
      manifest.indexOf('</queries>'),
    );

    expect(queries, contains('android.intent.action.DIAL'));
    expect(queries, contains('android:scheme="tel"'));
  });
}
