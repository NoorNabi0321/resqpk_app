import 'package:flutter/material.dart';

import '../constants/app_text_styles.dart';

/// Wraps a top-level screen so the hardware back button does not close the app
/// on the first press. Accidentally exiting during an emergency is worse than
/// one extra tap.
class ExitGuard extends StatefulWidget {
  final Widget child;
  final String message;

  const ExitGuard({
    super.key,
    required this.child,
    this.message = 'Press back again to exit ResQPK',
  });

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        final withinWindow = _lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2);

        if (withinWindow) {
          Navigator.of(context).maybePop();
          return;
        }

        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(widget.message, style: AppTextStyles.body),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Sends the hardware back button to a specific route instead of letting it
/// pop an empty stack (which quits the app after a `context.go`).
class BackTo extends StatelessWidget {
  final Widget child;
  final VoidCallback onBack;

  const BackTo({super.key, required this.child, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onBack();
      },
      child: child,
    );
  }
}
