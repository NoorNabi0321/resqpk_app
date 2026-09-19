import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Full-width filled button with a built-in loading state.
///
/// `brandInk` rather than `brand`: white text on the logo's orange fails
/// contrast, and a button nobody can read is not a button. Red is reserved for
/// the emergency itself, so a form's submit button is never `critical`.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  final double height;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.color = Resq.brandInk,
    this.height = 52,
    this.icon,
  });

  /// The one button that starts or continues an emergency.
  const PrimaryButton.critical({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.height = 52,
    this.icon,
  }) : color = Resq.critical;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      // Never below the 48dp target: this gets tapped one-handed, in a hurry.
      height: height < Resq.tapTarget ? Resq.tapTarget : height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Resq.radiusControl)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: Resq.space2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: ResqType.button(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The quieter half of a pair. Same size and shape, so the two line up.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = Resq.brandInk,
    this.height = 52,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height < Resq.tapTarget ? Resq.tapTarget : height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Resq.radiusControl)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Resq.space2),
            ],
            Flexible(
              child: Text(
                label,
                style: ResqType.button(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
