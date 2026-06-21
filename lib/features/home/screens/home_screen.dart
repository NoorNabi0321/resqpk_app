import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';

// Placeholder patient home — the SOS button and map arrive in Module 4.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${user?.fullName ?? "User"}!', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text('Module 4 will add the SOS button here',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(authProvider.notifier).logout().then((_) {
                if (context.mounted) context.go(Routes.roleSelect);
              }),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
