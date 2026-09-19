import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A strip that appears when the connection drops.
///
/// It says what still works rather than only what does not. Someone offline in
/// an emergency needs to know that first aid is cached and that 1122 does not
/// need the internet.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    if (online) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Resq.decisionTint,
      padding: const EdgeInsets.symmetric(horizontal: Resq.space4, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Resq.decision),
          const SizedBox(width: Resq.space2),
          Expanded(
            child: Text(
              message ?? 'No internet. First aid still works, and 1122 can always be called.',
              style: ResqType.caption(color: Resq.decision),
            ),
          ),
        ],
      ),
    );
  }
}
