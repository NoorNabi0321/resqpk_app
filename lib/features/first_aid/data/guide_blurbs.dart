// The one line each guide shows on its card: when you would reach for it.
//
// It lives here rather than beside the card because the repository searches
// it. Someone who reads "Fire, hot oil, steam, chemicals or electricity" on
// the burns card and types "fire" expects the burns card, and used to get
// "Nothing matches" — the words on screen were not in anything searched.
import 'models/first_aid_guide_model.dart';

const Map<String, String> whenToUse = {
  'cpr-guide': 'Not breathing, no pulse. Chest compressions.',
  'choking-guide': 'Cannot speak, cough or breathe. Blocked airway.',
  'burns-guide': 'Fire, hot oil, steam, chemicals or electricity.',
  'snake-bite-guide': 'Bitten by a snake. Keep them still.',
  'bleeding-control-guide': 'Heavy bleeding that will not stop.',
  'fracture-guide': 'Possible broken bone. Swelling, pain or deformity.',
  'heatstroke-guide': 'Too hot, confused or collapsed in the sun.',
  'eye-injury-guide': 'Object, chemicals, dust or trauma to the eye.',
};

const Map<String, String> whenToUseUr = {
  'cpr-guide': 'سانس نہیں آ رہا، نبض بند ہے۔',
  'choking-guide': 'گلے میں کچھ پھنس گیا، سانس بند ہے۔',
  'burns-guide': 'آگ، گرم تیل، بھاپ یا کیمیکل سے جلنا۔',
  'snake-bite-guide': 'سانپ نے کاٹا ہے۔ مریض کو ہلنے نہ دیں۔',
  'bleeding-control-guide': 'خون بہہ رہا ہے اور رک نہیں رہا۔',
  'fracture-guide': 'ہڈی ٹوٹ سکتی ہے۔ سوجن یا شدید درد۔',
  'heatstroke-guide': 'دھوپ میں زیادہ گرمی، بے ہوشی یا الجھن۔',
  'eye-injury-guide': 'آنکھ میں چیز، کیمیکل، مٹی یا چوٹ۔',
};

String guideBlurb(FirstAidGuideModel guide, String language) {
  final table = language == 'ur' ? whenToUseUr : whenToUse;
  final blurb = table[guide.slug];
  if (blurb != null) return blurb;

  // Unknown slug — a guide added after this build. Fall back to its own first
  // step, which is real content rather than an invented description.
  final steps = guide.getSteps(language);
  return steps.isEmpty ? guide.getTitle(language) : steps.first.instruction;
}
