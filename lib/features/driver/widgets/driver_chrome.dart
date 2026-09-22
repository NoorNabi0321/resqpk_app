import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// Page chrome for every driver screen.
///
/// The same warm page the patient app is written on.
///
/// The driver side ran dark for a while — the argument being a phone mounted
/// in a cab at night — but one product reading as one product wins: a driver
/// and a patient looking at the same case now see the same colours meaning the
/// same things, and there is one palette to maintain instead of two.
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
    return Scaffold(
      backgroundColor: Resq.canvas,
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
                      icon: const Icon(Icons.arrow_back_rounded, color: Resq.ink),
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
                          style: ResqType.title(),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ResqType.caption(),
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
    );
  }
}

/// The card, driver side — same white surface and hairline as the patient app.
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

  static const double _accentWidth = 4;

  @override
  Widget build(BuildContext context) {
    // The accent stripe is a Positioned child of a Stack, not a stretched Row
    // child. `CrossAxisAlignment.stretch` in a Row asks every child to fill the
    // cross axis, which inside a ListView is infinite — that assertion killed
    // the layout of every card on this screen, and in a release build a failed
    // widget paints as an empty box. It is why the driver dashboard showed a
    // duty toggle and then nothing at all.
    final card = Container(
      decoration: BoxDecoration(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        border: Border.all(color: Resq.border),
        boxShadow: Resq.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: accent == null
                ? padding
                : padding.copyWith(left: padding.left + _accentWidth),
            child: child,
          ),
          if (accent != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _accentWidth,
              child: ColoredBox(color: accent!),
            ),
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
    this.color = Resq.ink,
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
          Text(label, maxLines: 2, style: ResqType.caption()),
        ],
      ),
    );
  }
}

/// What the driver is doing right now, as one enormous control.
///
/// Four states, because "off duty" and "the socket has not connected yet" are
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

  ({Color color, Color tint, String label, String hint, IconData icon}) get _look =>
      switch (state) {
        DutyState.online => (
            color: Resq.ready,
            tint: Resq.readyTint,
            label: 'On duty',
            hint: 'Tap to stop receiving emergencies',
            icon: Icons.check_circle_rounded,
          ),
        DutyState.onCase => (
            color: Resq.info,
            tint: Resq.infoTint,
            label: 'On a case',
            hint: 'Finish the run before going off duty',
            icon: Icons.local_shipping_rounded,
          ),
        DutyState.connecting => (
            color: Resq.decision,
            tint: Resq.decisionTint,
            label: 'Connecting…',
            hint: 'Reaching the ResQPK server',
            icon: Icons.sync_rounded,
          ),
        DutyState.offline => (
            color: Resq.inkMuted,
            tint: Resq.surfaceAlt,
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
          color: live ? look.tint : Resq.surface,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          border: Border.all(color: live ? look.color : Resq.border, width: live ? 1.5 : 1),
          boxShadow: Resq.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: look.tint, shape: BoxShape.circle),
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
                  Text(look.label, style: ResqType.title(color: live ? look.color : Resq.ink)),
                  const SizedBox(height: 2),
                  Text(look.hint, style: ResqType.caption()),
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
    final color = onTap == null ? Resq.inkFaint : (tint ?? Resq.inkSoft);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: Resq.tapTarget,
        height: Resq.tapTarget,
        decoration: BoxDecoration(
          color: Resq.surface,
          shape: BoxShape.circle,
          border: Border.all(color: tint?.withValues(alpha: 0.5) ?? Resq.border),
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

/// Full-width action.
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
          disabledBackgroundColor: Resq.surfaceAlt,
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
