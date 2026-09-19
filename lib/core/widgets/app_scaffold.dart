import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'offline_banner.dart';

/// Page chrome for takeover screens — the ones outside the tab shell.
///
/// Gives every screen the same header, the same back affordance and the same
/// offline banner, so screens stop inventing their own and drifting apart.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.showBack = true,
    this.padding = const EdgeInsets.symmetric(horizontal: Resq.space4),
    this.backgroundColor,
    this.bottomBar,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Resq.canvas,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (title != null || showBack)
              Padding(
                padding: const EdgeInsets.fromLTRB(Resq.space2, Resq.space2, Resq.space3, Resq.space2),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: Resq.ink,
                        // 48dp, because this is tapped one-handed in a hurry.
                        constraints: const BoxConstraints(
                          minWidth: Resq.tapTarget,
                          minHeight: Resq.tapTarget,
                        ),
                      ),
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: ResqType.title(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    ...?actions,
                  ],
                ),
              ),
            const OfflineBanner(),
            Expanded(child: Padding(padding: padding, child: body)),
          ],
        ),
      ),
    );
  }
}
