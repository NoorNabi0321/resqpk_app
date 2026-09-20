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
  'road-accident-guide': 'Crash injuries. Do not move a neck or spine.',
  'drowning-guide': 'Pulled from water, not breathing properly.',
  'cardiac-arrest-guide': 'Sudden collapse, chest pain, gasping.',
  'bleeding-control-guide': 'Heavy bleeding that will not stop.',
};

/// Urdu equivalents, so the card reads as one language rather than two.
const Map<String, String> _whenToUseUr = {
  'cpr-guide': 'سانس نہیں آ رہا، نبض بند ہے۔',
  'choking-guide': 'گلے میں کچھ پھنس گیا، سانس بند ہے۔',
  'burns-guide': 'آگ، گرم تیل، بھاپ یا کیمیکل سے جلنا۔',
  'snake-bite-guide': 'سانپ نے کاٹا ہے۔ مریض کو ہلنے نہ دیں۔',
  'road-accident-guide': 'حادثے کی چوٹیں۔ گردن کو نہ ہلائیں۔',
  'drowning-guide': 'پانی سے نکالا گیا، سانس ٹھیک نہیں۔',
  'cardiac-arrest-guide': 'اچانک گر جانا، سینے میں درد۔',
  'bleeding-control-guide': 'خون بہہ رہا ہے اور رک نہیں رہا۔',
};

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
/// Was a two-up grid of square tiles, where the title wrapped to two lines and
/// there was no room to say what the guide was for. A full-width row fits the
/// category, the line that matters, and the picture — and stacks in the order
/// someone would scan them.
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

    return Padding(
      padding: const EdgeInsets.only(bottom: Resq.space3),
      child: Material(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          child: Directionality(
            // In Urdu the whole row mirrors: stripe and text on the right,
            // picture on the left. Half-mirrored layouts read as broken.
            textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              // Nastaliq needs 1.8 line height to keep its descenders off the
              // line below, so the same three lines of text are a third taller
              // in Urdu. One height for both languages clipped the Urdu.
              //
              // The slack on top of the measured minimum is deliberate: the
              // font falls back on some devices, and a first-aid card that
              // clips its own description is worse than one with a little air.
              height: urdu ? 148 : 122,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Resq.radiusCard),
                border: Border.all(color: Resq.border),
                boxShadow: Resq.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  // The coral spine. Identical on every card on purpose: it is
                  // what makes the list read as one set of things.
                  Container(width: 6, color: Resq.brand),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Resq.space4,
                        Resq.space3,
                        Resq.space3,
                        Resq.space3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _shortName(guide, language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: urdu
                                ? ResqType.nastaliq(size: 18)
                                : ResqType.section(),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            guideBlurb(guide, language),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: urdu
                                ? ResqType.nastaliq(size: 13, color: Resq.inkSoft)
                                : ResqType.caption(color: Resq.inkSoft),
                          ),
                          const SizedBox(height: Resq.space2),
                          _MetaRow(steps: steps, illustrated: cover != null, urdu: urdu),
                        ],
                      ),
                    ),
                  ),
                  _Cover(path: cover, category: guide.category),
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
    // Flexible, not fixed: on a 320dp phone — and with whatever font the
    // device actually falls back to — this row is the first thing to run out
    // of width, and an overflow stripe across a first-aid card is not a thing
    // anyone should ever see.
    return Row(
      children: [
        const Icon(Icons.list_rounded, size: 13, color: Resq.inkFaint),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            urdu ? '$steps مراحل' : '$steps steps',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ResqType.micro(),
          ),
        ),
        if (illustrated) ...[
          const SizedBox(width: Resq.space3),
          const Icon(Icons.image_rounded, size: 13, color: Resq.ready),
          const SizedBox(width: 4),
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
  const _Cover({required this.path, required this.category});

  final String? path;
  final String category;

  static const Map<String, String> _emoji = {
    'CPR': '❤️',
    'Choking': '🫁',
    'Burns': '🔥',
    'Snake Bite': '🐍',
    'Road Accident': '🚗',
    'Drowning': '🌊',
    'Cardiac Arrest': '⚡',
    'Bleeding': '🩸',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: double.infinity,
      child: path == null
          ? Container(
              color: Resq.brandTint,
              alignment: Alignment.center,
              child: Text(_emoji[category] ?? '🩹', style: const TextStyle(fontSize: 34)),
            )
          : Image.asset(
              path!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Resq.brandTint,
                alignment: Alignment.center,
                child: Text(_emoji[category] ?? '🩹', style: const TextStyle(fontSize: 34)),
              ),
            ),
    );
  }
}
