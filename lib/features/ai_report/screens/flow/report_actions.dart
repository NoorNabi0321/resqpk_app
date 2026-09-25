import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// The action bar every step of the report flow ends with.
///
/// One widget because four screens were each laying out their own pair, and
/// they drifted: different flex, different labels, different heights. The
/// narrow half could not fit "Record again", so it wrapped to "Reco / rd /
/// agai / n" — three screens, three different shapes of broken.
///
/// Equal halves, and icons rather than words. At this point in the flow the
/// screen title already says what is being done; the buttons only have to say
/// which way — back to redo, forward to continue.
class ReportActions extends StatelessWidget {
  const ReportActions({
    super.key,
    required this.actions,
    this.busy = false,
  });

  /// Two or three, laid out in equal shares of the width.
  final List<ReportAction> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: Resq.space3),
          Expanded(child: _ActionButton(action: actions[i], busy: busy)),
        ],
      ],
    );
  }
}

class ReportAction {
  const ReportAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.color,
  });

  final IconData icon;

  /// Read aloud by screen readers, and shown on a long press — the only words
  /// on the button, and only when someone asks for them.
  final String tooltip;
  final VoidCallback? onPressed;

  /// The one that carries the flow forward.
  final bool filled;
  final Color? color;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.busy});

  final ReportAction action;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = action.color ?? (action.filled ? Resq.critical : Resq.inkSoft);
    final enabled = action.onPressed != null && !busy;

    final child = busy && action.filled
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Icon(
            action.icon,
            size: 28,
            color: action.filled ? Colors.white : (enabled ? color : Resq.inkFaint),
          );

    return Tooltip(
      message: action.tooltip,
      child: SizedBox(
        height: 60,
        child: action.filled
            ? ElevatedButton(
                onPressed: enabled ? action.onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  disabledBackgroundColor: Resq.surfaceAlt,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Resq.radiusControl),
                  ),
                ),
                child: child,
              )
            : OutlinedButton(
                onPressed: enabled ? action.onPressed : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: enabled ? Resq.border : Resq.surfaceAlt),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Resq.radiusControl),
                  ),
                ),
                child: child,
              ),
      ),
    );
  }
}
