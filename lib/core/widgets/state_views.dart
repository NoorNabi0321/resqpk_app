import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Nothing to show — and an explanation of why, plus a way forward.
///
/// Every empty screen in this app used to be a line of grey text. An empty
/// state that does not say what to do next is a dead end.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Resq.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(illustration, width: 220, fit: BoxFit.contain),
            const SizedBox(height: Resq.space4),
            Text(title, style: ResqType.section(), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Resq.space2),
              Text(message!, style: ResqType.body(color: Resq.inkMuted), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Resq.space5),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(backgroundColor: Resq.brandInk),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Something failed. Say what, in plain words, and always leave a way out —
/// in this app that means a phone number that works when the app does not.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.onRetry,
    this.onCall,
  });

  final String illustration;
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Resq.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(illustration, width: 220, fit: BoxFit.contain),
            const SizedBox(height: Resq.space4),
            Text(title, style: ResqType.section(), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Resq.space2),
              Text(message!, style: ResqType.body(color: Resq.inkMuted), textAlign: TextAlign.center),
            ],
            const SizedBox(height: Resq.space5),
            if (onRetry != null)
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            if (onCall != null) ...[
              const SizedBox(height: Resq.space2),
              ElevatedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call Rescue 1122'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer blocks shaped like the content that is coming.
///
/// A skeleton that matches the real layout reads as "nearly there"; a spinner
/// reads as "something might be broken".
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.lines = 3, this.height = 96});

  final int lines;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Resq.surfaceAlt,
      highlightColor: Resq.surface,
      child: Column(
        children: [
          for (var i = 0; i < lines; i++)
            Container(
              height: height,
              margin: const EdgeInsets.only(bottom: Resq.space3),
              decoration: BoxDecoration(
                color: Resq.surface,
                borderRadius: BorderRadius.circular(Resq.radiusCard),
              ),
            ),
        ],
      ),
    );
  }
}
