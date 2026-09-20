import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// Page chrome for every driver screen.
///
/// Drivers work at night with the phone mounted on a dashboard, so their half
/// of the app is dark — a white screen at 2am is genuinely dangerous, and it
/// reflects off a windscreen. The accent colours are the same ones the patient
/// app uses: an ambulance is the same blue on both sides of the system.
class DriverScaffold extends StatelessWidget {
  const DriverScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.bottomBar,
    this.onBack,
    this.padding = const EdgeInsets.symmetric(horizontal: Resq.space4),
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final VoidCallback? onBack;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Wrapped rather than inherited: dialogs and sheets opened from a driver
    // screen read the ambient theme, and a white sheet over a dark map is the
    // flash of light this whole palette exists to avoid.
    return Theme(
      data: ResqTheme.dark,
      child: Scaffold(
        backgroundColor: ResqDark.canvas,
        bottomNavigationBar: bottomBar,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Resq.space3,
                  Resq.space2,
                  Resq.space4,
                  Resq.space3,
                ),
                child: Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded, color: ResqDark.ink),
                        constraints: const BoxConstraints(
                          minWidth: Resq.tapTarget,
                          minHeight: Resq.tapTarget,
                        ),
                      )
                    else
                      const SizedBox(width: Resq.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ResqType.title(color: ResqDark.ink),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ResqType.caption(color: ResqDark.inkMuted),
                            ),
                        ],
                      ),
                    ),
                    ...?actions,
                  ],
                ),
              ),
              Expanded(child: Padding(padding: padding, child: body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card, in driver dark.
class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Resq.space4),
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: ResqDark.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        border: Border.all(color: accent ?? ResqDark.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (accent != null) Container(width: 3, color: accent),
          Expanded(child: Padding(padding: padding, child: child)),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Resq.radiusCard),
      child: card,
    );
  }
}

/// One number, said plainly.
///
/// Drivers here are volunteers — Edhi and Chhipa crews are not paid per run —
/// so counting what they have answered is the least the app owes them.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color = ResqDark.ink,
    this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      padding: const EdgeInsets.symmetric(horizontal: Resq.space3, vertical: Resq.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(height: Resq.space2),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ResqType.title(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: ResqType.caption(color: ResqDark.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// What the driver is doing right now, as one enormous control.
///
/// Four states, because "offline" and "the socket has not connected yet" are
/// different problems and only one of them is the driver's to fix.
enum DutyState { offline, connecting, online, onCase }

class DutyToggle extends StatelessWidget {
  const DutyToggle({
    super.key,
    required this.state,
    required this.onTap,
    this.busy = false,
  });

  final DutyState state;
  final VoidCallback? onTap;
  final bool busy;

  ({Color color, String label, String hint, IconData icon}) get _look => switch (state) {
        DutyState.online => (
            color: Resq.ready,
            label: 'On duty',
            hint: 'Tap to stop receiving emergencies',
            icon: Icons.check_circle_rounded,
          ),
        DutyState.onCase => (
            color: Resq.info,
            label: 'On a case',
            hint: 'Finish the run before going off duty',
            icon: Icons.local_shipping_rounded,
          ),
        DutyState.connecting => (
            color: Resq.decision,
            label: 'Connecting…',
            hint: 'Reaching the ResQPK server',
            icon: Icons.sync_rounded,
          ),
        DutyState.offline => (
            color: ResqDark.inkMuted,
            label: 'Off duty',
            hint: 'Tap to start receiving emergencies',
            icon: Icons.power_settings_new_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final live = state == DutyState.online || state == DutyState.onCase;

    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: Resq.space5, horizontal: Resq.space5),
        decoration: BoxDecoration(
          color: live ? look.color.withValues(alpha: 0.16) : ResqDark.surface,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          border: Border.all(color: live ? look.color : ResqDark.border, width: live ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: look.color.withValues(alpha: live ? 0.22 : 0.12),
                shape: BoxShape.circle,
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: look.color),
                    )
                  : Icon(look.icon, color: look.color, size: 26),
            ),
            const SizedBox(width: Resq.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(look.label, style: ResqType.title(color: live ? look.color : ResqDark.ink)),
                  const SizedBox(height: 2),
                  Text(look.hint, style: ResqType.caption(color: ResqDark.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round control for map overlays and headers.
class DriverRoundButton extends StatelessWidget {
  const DriverRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tint,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? tint;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? ResqDark.inkFaint : (tint ?? ResqDark.ink);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: Resq.tapTarget,
        height: Resq.tapTarget,
        decoration: BoxDecoration(
          color: ResqDark.surface,
          shape: BoxShape.circle,
          border: Border.all(color: tint ?? ResqDark.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            if (badge > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Resq.critical,
                    borderRadius: BorderRadius.all(Radius.circular(Resq.radiusPill)),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: ResqType.micro(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-width action, dark side.
class DriverButton extends StatelessWidget {
  const DriverButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Resq.ready,
    this.icon,
    this.busy = false,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: ResqDark.surfaceHigh,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Resq.radiusControl)),
        ),
        child: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: Resq.space2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ResqType.button(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
