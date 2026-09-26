import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/router/app_router.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.headline,
    required this.highlight,
    required this.body,
    required this.illustration,
  });

  final String headline;

  /// The part of [headline] set in the brand colour.
  ///
  /// Held separately rather than marked up inline so the copy stays one
  /// readable string — and so a headline whose highlight gets reworded cannot
  /// silently lose its emphasis: [_Headline] asserts the two still agree.
  final String highlight;

  final String body;
  final String illustration;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  // Three promises, in the order they matter: help comes, the hospital is
  // ready, and you choose which one. No account is mentioned, because none is
  // needed to do any of it.
  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      headline: 'Hold SOS.\nThat is all.',
      highlight: 'SOS',
      body: 'No sign-up, no password. Hold the button for three seconds '
          'and the nearest ambulances are offered your emergency.',
      illustration: AppAssets.onboardingSos,
    ),
    _OnboardingPage(
      headline: 'The hospital knows\nbefore you arrive',
      highlight: 'knows',
      body: 'Your location, and anything you tell us on the way, reaches '
          'the emergency ward while the ambulance is still moving.',
      illustration: AppAssets.onboardingHospital,
    ),
    _OnboardingPage(
      headline: 'Your hospital,\nyour choice',
      highlight: 'hospital,',
      body: 'Take the nearest one or pick another. Only the hospital you '
          'confirm is alerted.',
      illustration: AppAssets.onboardingChoice,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    // Straight to the SOS button. Choosing a role is something drivers do from
    // More; a patient has nothing to choose.
    context.go(Routes.home);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The artwork is bright sky at the top and near-black at the bottom, so
      // the clock wants dark glyphs and the navigation bar light ones.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _scrimInk,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _scrimInk,
        // The illustration runs under the status bar; only the controls at the
        // bottom are inset, and they do that themselves.
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _Slide(page: _pages[i]),
            ),
            // Outside the PageView, so it does not slide with the artwork. The
            // text swaps under a scrim that stays put.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Resq.space6,
                    0,
                    Resq.space6,
                    Resq.space5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Headline(page: _pages[_index]),
                      const SizedBox(height: Resq.space4),
                      Text(
                        _pages[_index].body,
                        style: ResqType.body(color: Colors.white).copyWith(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: Resq.space6),
                      Center(child: _Dots(count: _pages.length, index: _index)),
                      const SizedBox(height: Resq.space5),
                      _StartButton(
                        label: last ? 'Get Started' : 'Next',
                        onPressed: _next,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ink the artwork fades into. Near-black, faintly blue, so the fade reads
/// as dusk over the illustration rather than a grey wash laid on top of it.
const Color _scrimInk = Color(0xFF0B1020);

/// One full-bleed illustration under a scrim that carries the text.
class _Slide extends StatelessWidget {
  const _Slide({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          page.illustration,
          // Cover, not contain: a band of background down the side of a
          // photographic illustration looks like a loading failure.
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => const ColoredBox(color: _scrimInk),
        ),
        // Four stops, not two. A single fade to black over the bottom half
        // dulls the middle of the picture; this leaves the top third alone
        // and then falls away quickly, which measures 13.7:1 under the
        // headline and 15:1 under the body on all three illustrations.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.38, 0.62, 1.0],
              colors: [
                Colors.transparent,
                Color(0x1A0B1020),
                Color(0xDD0B1020),
                Color(0xFC0B1020),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The headline, with one word or phrase in the brand colour.
class _Headline extends StatelessWidget {
  const _Headline({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final style = ResqType.display(color: Colors.white).copyWith(
      fontSize: 34,
      height: 1.18,
      letterSpacing: -0.5,
    );

    final at = page.headline.indexOf(page.highlight);
    // A highlight that no longer appears in its headline means the copy was
    // edited and the emphasis left behind. Losing it is not worth crashing
    // over in someone's hands, so release builds just set the line plainly.
    assert(
      at >= 0,
      'Onboarding highlight "${page.highlight}" is not in "${page.headline}"',
    );
    if (at < 0) return Text(page.headline, style: style);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: page.headline.substring(0, at)),
          TextSpan(
            text: page.highlight,
            style: const TextStyle(color: Resq.brandOnDark),
          ),
          TextSpan(text: page.headline.substring(at + page.highlight.length)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              // The lifted brand, like the headline: the plain one is 2.9:1
              // against the scrim here, under the 3:1 a UI component needs.
              color: i == index ? Resq.brandOnDark : Colors.white.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(Resq.radiusPill),
            ),
          ),
      ],
    );
  }
}

/// The one action on the screen, so it gets the full width and a big target.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Resq.brand,
      borderRadius: BorderRadius.circular(Resq.radiusPill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(Resq.radiusPill),
        // Width is explicit. The column above aligns to start, which hands its
        // children loose constraints, and the Stack inside then shrank to the
        // width of the word "Next" — a 77px button pinned to the left edge.
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centred against the button, not against the space left over
              // beside the arrow — otherwise the label sits visibly left.
              //
              // 19/bold is deliberate, not taste. tokens.dart warns that a
              // white label on `brand` fails contrast and should use
              // `brandInk`; that holds at normal size, where brand is 3.4:1
              // against white. At 19px bold this counts as large text, where
              // the bar is 3:1, so the button can keep the vivid coral the
              // design calls for. Shrink this text and the rule bites again.
              Text(
                label,
                style: ResqType.button(color: Colors.white).copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Positioned(
                right: Resq.space6,
                child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
