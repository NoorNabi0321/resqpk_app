import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/constants/app_assets.dart';
import 'package:resqpk_app/features/first_aid/data/first_aid_repository.dart';
import 'package:resqpk_app/features/first_aid/data/guide_blurbs.dart';
import 'package:resqpk_app/features/first_aid/data/models/first_aid_guide_model.dart';

/// Search has to find a guide by the words printed on its own card.
///
/// It used to cover the title, the category and the step instructions, but not
/// the one line the card actually shows. "Fire, hot oil, steam, chemicals or
/// electricity" is on the burns card, and "fire", "oil" and "electric" all
/// returned nothing — which reads as the search being broken, because from
/// where the reader sits it is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FirstAidGuideModel> guides;
  final repo = FirstAidRepository();

  setUpAll(() async {
    final raw = await rootBundle.loadString(AppAssets.firstAidGuides);
    guides = (jsonDecode(raw) as List)
        .map((e) => FirstAidGuideModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  List<String> slugsFor(String query, [String language = 'en']) =>
      repo.searchGuides(guides, query, language).map((g) => g.slug).toList();

  test('every word on a card finds that card', () {
    // The blurb is what the reader has in front of them, so every word in it
    // is a word they might reasonably type.
    for (final guide in guides) {
      final blurb = guideBlurb(guide, 'en');
      final words = blurb
          .toLowerCase()
          .split(RegExp(r'[^a-z]+'))
          .where((w) => w.length > 3)
          .toSet();

      for (final word in words) {
        expect(
          slugsFor(word),
          contains(guide.slug),
          reason: '"$word" is printed on the ${guide.slug} card and does not find it',
        );
      }
    }
  });

  test('the words that used to return nothing', () {
    expect(slugsFor('fire'), contains('burns-guide'));
    expect(slugsFor('oil'), contains('burns-guide'));
    expect(slugsFor('electric'), contains('burns-guide'));
    expect(slugsFor('sun'), contains('heatstroke-guide'));
  });

  test('finds by title and category', () {
    expect(slugsFor('cpr'), contains('cpr-guide'));
    expect(slugsFor('snake'), contains('snake-bite-guide'));
    expect(slugsFor('choking'), contains('choking-guide'));
    expect(slugsFor('bone'), contains('fracture-guide'));
  });

  test('finds by what the emergency is called elsewhere', () {
    // Words nobody prints on a card, but that a patient would type.
    expect(slugsFor('wound'), contains('bleeding-control-guide'));
    expect(slugsFor('cut'), contains('bleeding-control-guide'));
    expect(slugsFor('cardiac'), contains('cpr-guide'));
  });

  test('English search works while reading Urdu, and the other way round', () {
    // Nobody switches language in order to search.
    expect(slugsFor('burn', 'ur'), contains('burns-guide'));
    expect(slugsFor('snake', 'ur'), contains('snake-bite-guide'));
    // And an Urdu word while reading English.
    final urduTitle = guides.firstWhere((g) => g.slug == 'cpr-guide').getTitle('ur');
    expect(slugsFor(urduTitle, 'en'), contains('cpr-guide'));
  });

  test('an empty query is everything, nonsense is nothing', () {
    expect(slugsFor('').length, guides.length);
    expect(slugsFor('   ').length, guides.length);
    expect(slugsFor('zxqvwk'), isEmpty);
  });

  test('case and surrounding space do not matter', () {
    expect(slugsFor('  FiRe '), contains('burns-guide'));
    expect(slugsFor('SNAKE'), contains('snake-bite-guide'));
  });
}
