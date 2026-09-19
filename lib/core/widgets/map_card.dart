import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A map in a card: fixed height, rounded, hairline border, and isolated from
/// the rest of the page's painting.
///
/// The `RepaintBoundary` is the point of this widget. Without it, every pulse
/// of the SOS ring and every shimmer block on the same screen repaints the map
/// tiles underneath them, which is what made the home screen stutter.
class MapCard extends StatelessWidget {
  const MapCard({
    super.key,
    required this.child,
    this.height = 200,
    this.overlay,
    this.onTap,
  });

  /// The `FlutterMap` itself.
  final Widget child;
  final double height;

  /// Controls drawn on top of the map — recentre, open-in-maps, a legend.
  final Widget? overlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(Resq.radiusCard),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            RepaintBoundary(child: child),
            if (overlay != null) Positioned.fill(child: overlay!),
            // A hairline over the tiles, drawn last so the map cannot cover it.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Resq.radiusCard),
                    border: Border.all(color: Resq.border),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Small round control that sits on a map — recentre, navigate, layers.
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Resq.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: Resq.inkSoft),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
