import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One step of a first-aid guide.
class StepSliderItem {
  const StepSliderItem({
    required this.number,
    required this.title,
    required this.instruction,
    this.image,
  });

  final int number;
  final String title;
  final String instruction;

  /// Asset path for the illustration, or null when this guide has none yet.
  final String? image;
}

/// First aid, one step at a time.
///
/// The picture takes the screen and the words sit under it on a dark panel —
/// the two things do different jobs, so they get different grounds. Swipe the
/// picture or use the arrows beside the text; both move the same step, because
/// one hand may be holding a wound.
class StepSlider extends StatefulWidget {
  const StepSlider({
    super.key,
    required this.steps,
    this.rtl = false,
    this.onStepChanged,
  });

  final List<StepSliderItem> steps;

  /// Urdu reads right to left, and so do its step pages.
  final bool rtl;
  final ValueChanged<int>? onStepChanged;

  @override
  State<StepSlider> createState() => _StepSliderState();
}

class _StepSliderState extends State<StepSlider> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.steps.length) return;
    HapticFeedback.selectionClick();
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return Center(
        child: Text('This guide has no steps yet.', style: ResqType.body(color: Resq.inkMuted)),
      );
    }

    final step = widget.steps[_index];

    return Directionality(
      textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.steps.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                widget.onStepChanged?.call(i);
              },
              itemBuilder: (_, i) => _StepImage(step: widget.steps[i]),
            ),
          ),
          _StepPanel(
            step: step,
            index: _index,
            total: widget.steps.length,
            rtl: widget.rtl,
            onPrevious: _index == 0 ? null : () => _goTo(_index - 1),
            onNext: _index == widget.steps.length - 1 ? null : () => _goTo(_index + 1),
          ),
        ],
      ),
    );
  }
}

class _StepImage extends StatelessWidget {
  const _StepImage({required this.step});

  final StepSliderItem step;

  @override
  Widget build(BuildContext context) {
    if (step.image == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Resq.space4, Resq.space2, Resq.space4, Resq.space4),
        child: _NumberPlaceholder(number: step.number),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Resq.space4, Resq.space2, Resq.space4, Resq.space4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // The illustrations are drawn on white, so they get a white card
          // rather than sitting as a hard square on the cream page.
          color: Resq.surface,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          border: Border.all(color: Resq.border),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: Image.asset(
          step.image!,
          // Contain, never cover: a cropped first-aid illustration can lose
          // the hands, and the hands are the instruction.
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _NumberPlaceholder(number: step.number),
        ),
      ),
    );
  }
}

class _NumberPlaceholder extends StatelessWidget {
  const _NumberPlaceholder({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Resq.brandTint,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$number', style: ResqType.display(color: Resq.brandInk).copyWith(fontSize: 72)),
          Text('Step', style: ResqType.caption(color: Resq.brandInk)),
        ],
      ),
    );
  }
}

/// The dark panel the instruction lives on.
///
/// Dark because the illustration above it is bright and full of white: a light
/// card underneath made the two blur together, and the words are what someone
/// is actually trying to read.
class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.step,
    required this.index,
    required this.total,
    required this.rtl,
    required this.onPrevious,
    required this.onNext,
  });

  final StepSliderItem step;
  final int index;
  final int total;
  final bool rtl;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Resq.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Resq.space3, Resq.space4, Resq.space3, Resq.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dots(count: total, index: index),
              const SizedBox(height: Resq.space4),
              Row(
                children: [
                  _ArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPrevious,
                    tooltip: 'Previous step',
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Resq.brand,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${step.number}',
                                style: ResqType.micro(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: Resq.space2),
                            Flexible(
                              child: Text(
                                step.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: rtl
                                    ? ResqType.nastaliq(size: 17, color: Colors.white)
                                    : ResqType.section(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Resq.space2),
                        // Cream on navy: the same warm paper colour the rest of
                        // the app is written on, so the voice does not change.
                        Text(
                          step.instruction,
                          textAlign: TextAlign.center,
                          style: rtl
                              ? ResqType.nastaliq(size: 16, color: Resq.canvas)
                              : ResqType.body(color: Resq.canvas).copyWith(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                        ),
                      ],
                    ),
                  ),
                  _ArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNext,
                    tooltip: 'Next step',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: Resq.tapTarget,
          height: Resq.tapTarget,
          child: Icon(
            icon,
            size: 30,
            // The heading's colour, dimmed when there is nowhere to go — the
            // end of a guide should be visible before it is tapped for.
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.25),
          ),
        ),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == index ? Resq.brand : Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(Resq.radiusPill),
              ),
            ),
          ),
      ],
    );
  }
}

/// The number that works when nothing else does.
///
/// Kept for screens that still want it pinned to the bottom; the guide screen
/// itself is now deliberately bare, so the illustration owns the page.
class EmergencyCallBar extends StatelessWidget {
  const EmergencyCallBar({super.key, required this.onCall1122, this.trailing});

  final VoidCallback onCall1122;

  /// The second action — "Open SOS" normally, "Back to emergency" during a case.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Resq.surface,
        border: Border(top: BorderSide(color: Resq.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Resq.space4, Resq.space3, Resq.space4, Resq.space3),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall1122,
                  icon: const Icon(Icons.call_rounded, size: 18, color: Resq.critical),
                  label: Text('Call 1122', style: ResqType.button(color: Resq.critical)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(Resq.tapTarget),
                    side: BorderSide(color: Resq.critical.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Resq.space3),
                Expanded(child: trailing!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
