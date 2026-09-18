import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The card every screen uses: white surface, hairline border, one soft shadow.
///
/// Extracted because the same twelve lines of BoxDecoration were repeated on
/// every screen, drifting slightly each time — which is why nothing quite
/// matched anything else.
class ResqCard extends StatelessWidget {
  const ResqCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Resq.space4),
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// A 3px leading stripe — used sparingly, for urgency on a hospital card.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        border: Border.all(color: Resq.border),
        boxShadow: Resq.cardShadow,
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

/// A section title with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Resq.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(title, style: ResqType.section())),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Status as colour **and** icon **and** word.
///
/// Never colour alone: a colour-blind examiner should read this as easily as
/// anyone else, and so should a driver glancing at it in sunlight.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.tint,
    this.icon,
  });

  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;

  /// The four states the whole system speaks in.
  factory StatusPill.critical(String label) =>
      StatusPill(label: label, color: Resq.critical, tint: Resq.criticalTint, icon: Icons.priority_high);
  factory StatusPill.waiting(String label) =>
      StatusPill(label: label, color: Resq.decision, tint: Resq.decisionTint, icon: Icons.schedule);
  factory StatusPill.ready(String label) =>
      StatusPill(label: label, color: Resq.ready, tint: Resq.readyTint, icon: Icons.check_circle_outline);
  factory StatusPill.info(String label) =>
      StatusPill(label: label, color: Resq.info, tint: Resq.infoTint, icon: Icons.info_outline);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(Resq.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(label, style: ResqType.micro(color: color)),
        ],
      ),
    );
  }
}
