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
/// The old screen stacked every step in a scrolling list of collapsible cards.
/// That is a reference document, and someone kneeling next to a casualty is not
/// reading a reference document: they need one instruction, big enough to read
/// at arm's length, and a way to get to the next one without losing their place.
///
/// So: one step per page, the illustration doing most of the work, and a
/// position indicator that says how much is left. Swipe or tap — both work,
/// because one hand may be busy.
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
      duration: const Duration(milliseconds: 250),
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

    final last = _index == widget.steps.length - 1;

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
              itemBuilder: (_, i) => _StepPage(step: widget.steps[i], rtl: widget.rtl),
            ),
          ),
          const SizedBox(height: Resq.space3),
          _Dots(
            count: widget.steps.length,
            index: _index,
            onTap: _goTo,
          ),
          const SizedBox(height: Resq.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(Resq.tapTarget),
                    side: BorderSide(color: Resq.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
                    ),
                  ),
                  child: Text('Back', style: ResqType.button(color: Resq.inkSoft)),
                ),
              ),
              const SizedBox(width: Resq.space3),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: last ? null : () => _goTo(_index + 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Resq.brandInk,
                    disabledBackgroundColor: Resq.surfaceAlt,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(Resq.tapTarget),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
                    ),
                  ),
                  child: Text(
                    last ? 'Last step' : 'Next step',
                    style: ResqType.button(color: last ? Resq.inkMuted : Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.rtl});

  final StepSliderItem step;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Resq.surface,
              borderRadius: BorderRadius.circular(Resq.radiusCard),
              border: Border.all(color: Resq.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: step.image == null
                ? _NumberPlaceholder(number: step.number)
                : Image.asset(
                    step.image!,
                    fit: BoxFit.cover,
                    // Artwork is still missing for some guides; a step with no
                    // picture must still be readable, never a broken box.
                    errorBuilder: (_, __, ___) => _NumberPlaceholder(number: step.number),
                  ),
          ),
        ),
        const SizedBox(height: Resq.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Resq.brandInk, shape: BoxShape.circle),
              child: Text('${step.number}', style: ResqType.caption(color: Colors.white)),
            ),
            const SizedBox(width: Resq.space3),
            Expanded(child: Text(step.title, style: ResqType.section())),
          ],
        ),
        const SizedBox(height: Resq.space2),
        // Scrollable so a long instruction never overflows on a short phone —
        // and never gets silently clipped, which in first aid means a missing
        // instruction.
        SizedBox(
          height: 96,
          child: SingleChildScrollView(
            child: Text(
              step.instruction,
              style: rtl
                  ? ResqType.nastaliq(size: 17, color: Resq.ink)
                  : ResqType.body(color: Resq.ink).copyWith(fontSize: 17, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberPlaceholder extends StatelessWidget {
  const _NumberPlaceholder({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Resq.brandTint,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$number', style: ResqType.display(color: Resq.brandInk).copyWith(fontSize: 64)),
          Text('Step', style: ResqType.caption(color: Resq.brandInk)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.onTap});

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // Small dots, but a finger-sized tap area around each.
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index ? Resq.brandInk : Resq.border,
                  borderRadius: BorderRadius.circular(Resq.radiusPill),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The number that works when nothing else does.
///
/// Pinned to the bottom of every first-aid screen: reading a guide means help
/// is not there yet, and 1122 does not need the internet, an account, or this
/// app to be working properly.
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
