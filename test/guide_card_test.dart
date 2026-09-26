import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/constants/app_assets.dart';
import 'package:resqpk_app/features/first_aid/data/models/first_aid_guide_model.dart';
import 'package:resqpk_app/features/first_aid/data/guide_blurbs.dart';
import 'package:resqpk_app/features/first_aid/widgets/guide_card.dart';

/// The guide row has a fixed height and three stacked lines of text inside it,
/// which is exactly the shape that overflows silently on a narrow phone or in
/// a script with taller lines. These pump it at real phone widths, in both
/// languages, and fail on any overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FirstAidGuideModel> guides;

  setUpAll(() async {
    final raw = await rootBundle.loadString(AppAssets.firstAidGuides);
    guides = (jsonDecode(raw) as List)
        .map((e) => FirstAidGuideModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  Future<void> pumpCards(WidgetTester tester, String language, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final guide in guides)
                GuideCard(guide: guide, language: language, onTap: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('English cards lay out on a small phone', (tester) async {
    await pumpCards(tester, 'en', const Size(320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('English cards lay out on a normal phone', (tester) async {
    await pumpCards(tester, 'en', const Size(411, 891));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Urdu cards lay out — taller lines, mirrored row', (tester) async {
    await pumpCards(tester, 'ur', const Size(360, 780));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every guide has a line saying when to use it', (tester) async {
    for (final guide in guides) {
      final english = guideBlurb(guide, 'en');
      final urdu = guideBlurb(guide, 'ur');
      expect(english.trim(), isNotEmpty, reason: '${guide.slug} has no English blurb');
      expect(urdu.trim(), isNotEmpty, reason: '${guide.slug} has no Urdu blurb');
      // A blurb that is just the title tells the reader nothing new.
      expect(english, isNot(equals(guide.titleEn)), reason: '${guide.slug} blurb repeats the title');
    }
  });
}
