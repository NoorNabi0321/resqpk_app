import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/constants/app_assets.dart';
import 'package:resqpk_app/features/first_aid/data/models/first_aid_guide_model.dart';

/// First aid has to work on a phone that has never had a connection.
///
/// The guides are bundled into the APK for exactly that. These tests guard the
/// bundle itself: if it goes missing, or stops parsing, or loses a guide, a
/// patient standing over a casualty with no signal gets an empty screen — and
/// nothing else in the app would have noticed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FirstAidGuideModel> guides;

  setUpAll(() async {
    final raw = await rootBundle.loadString(AppAssets.firstAidGuides);
    guides = (jsonDecode(raw) as List)
        .map((e) => FirstAidGuideModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  test('the bundled guides parse into the model the screens use', () {
    expect(guides, isNotEmpty);
    for (final guide in guides) {
      expect(guide.id, isNotEmpty, reason: 'every guide needs an id');
      expect(guide.slug, isNotEmpty, reason: 'artwork is matched by slug');
      expect(guide.titleEn, isNotEmpty);
      expect(guide.stepsEn, isNotEmpty, reason: '${guide.slug} has no steps to follow');
    }
  });

  test('covers the emergencies the app dispatches for', () {
    final slugs = guides.map((g) => g.slug).toSet();
    for (final expected in [
      'cpr-guide',
      'choking-guide',
      'burns-guide',
      'snake-bite-guide',
      'road-accident-guide',
      'drowning-guide',
      'cardiac-arrest-guide',
      'bleeding-control-guide',
    ]) {
      expect(slugs, contains(expected));
    }
  });

  test('every step carries a readable instruction', () {
    for (final guide in guides) {
      for (final step in guide.stepsEn) {
        expect(step.instruction.trim(), isNotEmpty,
            reason: '${guide.slug} step ${step.step} is blank');
        expect(step.title.trim(), isNotEmpty);
      }
    }
  });

  test('Urdu is present, and in Urdu script', () {
    final urdu = guides.where((g) => (g.titleUr ?? '').isNotEmpty).toList();
    expect(urdu, isNotEmpty, reason: 'the app offers an Urdu toggle');

    // U+0600–U+06FF is the Arabic block Urdu is written in. A Latin string
    // here would mean the translation was lost somewhere in the export.
    final hasUrduScript = urdu.first.titleUr!.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
    expect(hasUrduScript, isTrue);
  });

  test('artwork lines up with the guides that have it', () {
    for (final guide in guides.where((g) => FirstAidArt.hasArt(g.slug))) {
      final steps = FirstAidArt.stepCount(guide.slug);
      expect(steps, greaterThan(0));
      expect(FirstAidArt.cover(guide.slug), isNotNull);
      // The slider asks for an image per step and falls back to a numbered
      // card; this only checks the mapping does not point past its folder.
      expect(FirstAidArt.step(guide.slug, steps), isNotNull);
      expect(FirstAidArt.step(guide.slug, steps + 1), isNull);
    }
  });
}
