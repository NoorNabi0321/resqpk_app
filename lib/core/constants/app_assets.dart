/// Every bundled asset path, in one place.
///
/// Screens never type a path literally: a typo in a string becomes a grey box
/// at runtime rather than an error at compile time, and these files are
/// referenced from several screens each.
class AppAssets {
  AppAssets._();

  // --- Brand ----------------------------------------------------------------
  // WebP for everything drawn inside the app. The PNG originals stay in
  // assets/brand/ as sources for the Android launcher and notification icons —
  // those must be PNG — but they are not bundled, because a 1 MB icon source
  // has no business travelling in the APK.
  static const String logoMark = 'assets/brand/logo-mark.webp';
  static const String logoWordmark = 'assets/brand/logo-wordmark.webp';
  static const String splashLogo = 'assets/brand/splash-logo.webp';

  // --- Motion ---------------------------------------------------------------
  static const String animSplash = 'assets/animations/splash.json';
  static const String animSearching = 'assets/animations/searching.json';
  static const String animSuccess = 'assets/animations/success.json';
  static const String animAmbulance = 'assets/animations/ambulance-moving.json';

  // --- Onboarding -----------------------------------------------------------
  static const String onboardingSos = 'assets/illustrations/onboarding-sos.webp';
  static const String onboardingHospital = 'assets/illustrations/onboarding-hospital.webp';
  static const String onboardingChoice = 'assets/illustrations/onboarding-choice.webp';

  // --- States ---------------------------------------------------------------
  static const String stateNoDriver = 'assets/illustrations/state-no-driver.webp';
  static const String stateLocationDenied = 'assets/illustrations/state-location-denied.webp';
  static const String stateOffline = 'assets/illustrations/state-offline.webp';
  static const String stateNoCamps = 'assets/illustrations/state-no-camps.webp';
  static const String stateNoRequests = 'assets/illustrations/state-no-requests.webp';
  static const String stateError = 'assets/illustrations/state-error.webp';
  static const String stateDriverOffline = 'assets/illustrations/state-driver-offline.webp';
  static const String stateNoHistory = 'assets/illustrations/state-no-history.webp';
}

/// Which first-aid guides have artwork, and how many steps each one has.
///
/// The guides themselves come from the backend, so this maps a server slug to a
/// local folder. Matching is by keyword rather than exact slug because the two
/// are maintained separately and a rename upstream should degrade to "no
/// picture", never to a crash or the wrong illustration.
class FirstAidArt {
  FirstAidArt._();

  static const Map<String, ({String folder, int steps})> _guides = {
    'cpr': (folder: 'cpr', steps: 6),
    'chok': (folder: 'choking', steps: 6),
    'bleed': (folder: 'bleeding', steps: 6),
    'burn': (folder: 'burns', steps: 5),
    'snake': (folder: 'snakebite', steps: 5),
    // Drawn, but with no guide behind them in the database yet. They cost
    // nothing while unmatched, and work the day those guides are added.
    'fractur': (folder: 'fracture', steps: 6),
    'heat': (folder: 'heatstroke', steps: 6),
    'eye': (folder: 'eye-injury', steps: 5),
    // Still unillustrated: road-accident, drowning and cardiac-arrest. Those
    // screens fall back to text-only steps.
  };

  static ({String folder, int steps})? _match(String slugOrTitle) {
    final key = slugOrTitle.toLowerCase();
    for (final entry in _guides.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// True when this guide can show illustrations.
  static bool hasArt(String slugOrTitle) => _match(slugOrTitle) != null;

  /// How many illustrated steps exist — burns has five, the rest six.
  static int stepCount(String slugOrTitle) => _match(slugOrTitle)?.steps ?? 0;

  /// Cover image for the guide list, or null when there is no artwork.
  static String? cover(String slugOrTitle) {
    final g = _match(slugOrTitle);
    return g == null ? null : 'assets/first_aid/${g.folder}/cover.webp';
  }

  /// Illustration for a 1-based step, or null when it does not exist.
  static String? step(String slugOrTitle, int oneBasedStep) {
    final g = _match(slugOrTitle);
    if (g == null || oneBasedStep < 1 || oneBasedStep > g.steps) return null;
    return 'assets/first_aid/${g.folder}/step-$oneBasedStep.webp';
  }
}
