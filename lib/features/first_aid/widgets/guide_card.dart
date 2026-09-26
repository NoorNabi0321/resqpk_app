import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../data/models/first_aid_guide_model.dart';

/// When to open each guide, in one line.
///
/// The card has to answer one question — "is this my situation?" — and a title
/// does not. "Treating Burns" tells you nothing about whether it covers the
/// hot oil on someone's arm. This is interface copy, not clinical content: the
/// steps inside are the guides themselves, straight from the backend.
const Map<String, String> _whenToUse = {
  'cpr-guide': 'Not breathing, no pulse. Chest compressions.',
  'choking-guide': 'Cannot speak, cough or breathe. Blocked airway.',
  'burns-guide': 'Fire, hot oil, steam, chemicals or electricity.',
  'snake-bite-guide': 'Bitten by a snake. Keep them still.',
  'bleeding-control-guide': 'Heavy bleeding that will not stop.',
  'fracture-guide': 'Possible broken bone. Swelling, pain or deformity.',
  'heatstroke-guide': 'Too hot, confused or collapsed in the sun.',
  'eye-injury-guide': 'Object, chemicals, dust or trauma to the eye.',
};

/// Urdu equivalents, so the card reads as one language rather than two.
const Map<String, String> _whenToUseUr = {
  'cpr-guide': 'سانس نہیں آ رہا، نبض بند ہے۔',
  'choking-guide': 'گلے میں کچھ پھنس گیا، سانس بند ہے۔',
  'burns-guide': 'آگ، گرم تیل، بھاپ یا کیمیکل سے جلنا۔',
  'snake-bite-guide': 'سانپ نے کاٹا ہے۔ مریض کو ہلنے نہ دیں۔',
  'bleeding-control-guide': 'خون بہہ رہا ہے اور رک نہیں رہا۔',
  'fracture-guide': 'ہڈی ٹوٹ سکتی ہے۔ سوجن یا شدید درد۔',
  'heatstroke-guide': 'دھوپ میں زیادہ گرمی، بے ہوشی یا الجھن۔',
  'eye-injury-guide': 'آنکھ میں چیز، کیمیکل، مٹی یا چوٹ۔',
};

/// The badge that stands in for the category, so a row is recognisable before
/// a word of it is read.
const Map<String, ({IconData icon, Color color, Color tint})> _badges = {
  'cpr-guide': (icon: Icons.monitor_heart_rounded, color: Resq.critical, tint: Resq.criticalTint),
  'choking-guide': (icon: Icons.air_rounded, color: Resq.critical, tint: Resq.criticalTint),
  'bleeding-control-guide':
      (icon: Icons.bloodtype_rounded, color: Resq.critical, tint: Resq.criticalTint),
  'burns-guide':
      (icon: Icons.local_fire_department_rounded, color: Resq.brand, tint: Resq.brandTint),
  'snake-bite-guide': (icon: Icons.healing_rounded, color: Resq.ready, tint: Resq.readyTint),
  'fracture-guide':
      (icon: Icons.personal_injury_rounded, color: Resq.decision, tint: Resq.decisionTint),
  'heatstroke-guide': (icon: Icons.thermostat_rounded, color: Resq.decision, tint: Resq.decisionTint),
  'eye-injury-guide': (icon: Icons.visibility_rounded, color: Resq.info, tint: Resq.infoTint),
};

const _fallbackBadge =
    (icon: Icons.medical_services_rounded, color: Resq.brandInk, tint: Resq.brandTint);

/// The same ground as every other card in the app — the emergency numbers on
/// the no-driver screen, the hospital rows, the tracking sheet.
///
/// It used to be #FCF8F2, a shade off white, on the theory that a card should
/// lift off the cream page without becoming a form field. Against the canvas
/// it read as grey, and grey is what a disabled control looks like.
const Color _cardCream = Resq.surface;

String guideBlurb(FirstAidGuideModel guide, String language) {
  final table = language == 'ur' ? _whenToUseUr : _whenToUse;
  final blurb = table[guide.slug];
  if (blurb != null) return blurb;

  // Unknown slug — a guide added after this build. Fall back to its own first
  // step, which is real content rather than an invented description.
  final steps = guide.getSteps(language);
  return steps.isEmpty ? guide.getTitle(language) : steps.first.instruction;
}

/// A guide, as a row you can read at a glance.
///
/// Badge, then the category and the line that matters, then the illustration —
/// which is drawn with BoxFit.contain on the card's own cream, because these
/// covers have their backgrounds removed and cropping one loses the very thing
/// it is showing.
class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.guide,
    required this.language,
    required this.onTap,
  });

  final FirstAidGuideModel guide;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urdu = language == 'ur';
    final cover = FirstAidArt.cover(guide.slug);
    final steps = guide.getSteps(language).length;
    final badge = _badges[guide.slug] ?? _fallbackBadge;

    return Padding(
      padding: const EdgeInsets.only(bottom: Resq.space3),
      child: Material(
        color: _cardCream,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          child: Directionality(
            // In Urdu the whole row mirrors: badge and text on the right,
            // picture on the left. Half-mirrored layouts read as broken.
            textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              // Taller, and the artwork runs the full height of it. The cover
              // is the fastest way to recognise a guide while scrolling, and
              // at the old size it was a thumbnail of a thumbnail.
              height: urdu ? 144 : 124,
              // Four points top and bottom so the tallest cover — eye injury,
              // which is nearly square — clears the corner radius instead of
              // being shaved by it. The picture still runs to the right edge.
              padding: const EdgeInsets.fromLTRB(Resq.space3, 4, 0, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Resq.radiusCard),
                border: Border.all(color: Resq.border),
                boxShadow: Resq.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: badge.tint, shape: BoxShape.circle),
                    child: Icon(badge.icon, size: 20, color: badge.color),
                  ),
                  const SizedBox(width: Resq.space3),
                  // Text gives up a share to the picture: 5:3 became 4:4, and
                  // the type comes down a point with it. The words are read
                  // second — the picture is what the eye lands on.
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _shortName(guide, language),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: urdu
                              ? ResqType.nastaliq(size: 15)
                              : ResqType.bodyStrong().copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          guideBlurb(guide, language),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: urdu
                              ? ResqType.nastaliq(size: 11, color: Resq.inkSoft)
                              : ResqType.caption(color: Resq.inkSoft).copyWith(fontSize: 11.5),
                        ),
                        const SizedBox(height: 5),
                        _MetaRow(steps: steps, illustrated: cover != null, urdu: urdu),
                      ],
                    ),
                  ),
                  const SizedBox(width: Resq.space2),
                  Expanded(
                    flex: 4,
                    child: _Cover(path: cover, badge: badge),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "CPR", not "How to Perform CPR".
  ///
  /// The category is the word someone is looking for when they are scanning,
  /// and it is already the short form; the full title lives on the guide.
  String _shortName(FirstAidGuideModel guide, String language) {
    if (language == 'ur') return guide.getTitle(language);
    return guide.category.isNotEmpty ? guide.category : guide.titleEn;
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.steps, required this.illustrated, required this.urdu});

  final int steps;
  final bool illustrated;
  final bool urdu;

  @override
  Widget build(BuildContext context) {
    // Flexible, not fixed: on a 320dp phone this row is the first thing to run
    // out of width, and an overflow stripe across a first-aid card is not a
    // thing anyone should ever see.
    return Row(
      children: [
        const Icon(Icons.list_rounded, size: 12, color: Resq.inkFaint),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            urdu ? '$steps مراحل' : '$steps steps',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ResqType.micro(),
          ),
        ),
        if (illustrated) ...[
          const SizedBox(width: Resq.space2),
          const Icon(Icons.image_rounded, size: 12, color: Resq.ready),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              urdu ? 'تصاویر' : 'With pictures',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ResqType.micro(color: Resq.ready),
            ),
          ),
        ],
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.path, required this.badge});

  final String? path;
  final ({IconData icon, Color color, Color tint}) badge;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return Center(
        child: Icon(badge.icon, size: 40, color: badge.color.withValues(alpha: 0.35)),
      );
    }

    return Image.asset(
      path!,
      // Contain, never cover. These covers are background-removed artwork on
      // the card's own cream; cropping one cuts off the thing it is showing.
      fit: BoxFit.contain,
      alignment: Alignment.centerRight,
      errorBuilder: (_, __, ___) => Center(
        child: Icon(badge.icon, size: 40, color: badge.color.withValues(alpha: 0.35)),
      ),
    );
  }
}
