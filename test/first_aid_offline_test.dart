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
      'bleeding-control-guide',
      'burns-guide',
      'snake-bite-guide',
      'fracture-guide',
      'heatstroke-guide',
      'eye-injury-guide',
    ]) {
      expect(slugs, contains(expected));
    }
  });

  test('every guide is illustrated', () {
    // The library and the artwork folders are meant to be the same eight
    // things. A guide with no pictures is the one people stop reading, and a
    // folder with no guide is artwork nobody can reach.
    for (final guide in guides) {
      expect(
        FirstAidArt.hasArt(guide.slug),
        isTrue,
        reason: '${guide.slug} has no illustrations in assets/first_aid/',
      );
      expect(
        FirstAidArt.stepCount(guide.slug),
        greaterThanOrEqualTo(guide.stepsEn.length),
        reason: '${guide.slug} has more steps than it has step pictures',
      );
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

  // U+0600–U+06FF is the Arabic block Urdu is written in. Latin text here
  // would mean the translation was lost somewhere in the export — or never
  // written, and the English quietly took its place.
  bool inUrduScript(String s) => s.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

  test('every guide answers the Urdu toggle', () {
    // getSteps() falls back to English when stepsUr is empty, so a missing
    // translation does not throw or show a gap — it hands back the English
    // steps and the reader has no way to tell the toggle did nothing. Four
    // guides shipped like that. Only a test at the data can catch it.
    for (final guide in guides) {
      expect(guide.titleUr?.trim() ?? '', isNotEmpty,
          reason: '${guide.slug} has no Urdu title');
      expect(inUrduScript(guide.titleUr!), isTrue,
          reason: '${guide.slug} title_ur is not in Urdu script');

      expect(guide.stepsUr ?? [], isNotEmpty,
          reason: '${guide.slug} has no Urdu steps — the toggle shows English');
      expect(guide.stepsUr!.length, guide.stepsEn.length,
          reason: '${guide.slug} has ${guide.stepsUr!.length} Urdu steps '
              'against ${guide.stepsEn.length} English');
    }
  });

  test('every Urdu step is written, numbered and in script', () {
    for (final guide in guides) {
      for (var i = 0; i < guide.stepsUr!.length; i++) {
        final step = guide.stepsUr![i];
        final where = '${guide.slug} Urdu step ${i + 1}';

        expect(step.title.trim(), isNotEmpty, reason: '$where has no title');
        expect(step.instruction.trim(), isNotEmpty, reason: '$where is blank');
        expect(inUrduScript(step.instruction), isTrue,
            reason: '$where is not in Urdu script');
        // The slider renders by position but labels by step number; a guide
        // translated out of order would put step 4's words under step 2.
        expect(step.step, guide.stepsEn[i].step,
            reason: '$where does not line up with the English it mirrors');
      }
    }
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
