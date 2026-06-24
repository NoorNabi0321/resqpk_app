import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../providers/sos_provider.dart';

class _Service {
  final String name;
  final String number;
  final String emoji;
  const _Service(this.name, this.number, this.emoji);
}

const _services = [
  _Service('Rescue 1122', '1122', '🚑'),
  _Service('Edhi Foundation', '115', '🏥'),
  _Service('Chhipa Welfare', '1020', '🩺'),
  _Service('Police Emergency', '15', '👮'),
];

class NoDriverScreen extends ConsumerWidget {
  const NoDriverScreen({super.key});

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.warningAmber, Color(0xFF7A5200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(Icons.no_transfer, color: Colors.white, size: 56),
                ),
              ),
              const SizedBox(height: 20),
              Text('No Ambulance Available', style: AppTextStyles.display.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                'All drivers are busy. Please use these emergency numbers.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final s = _services[i];
                    return InkWell(
                      onTap: () => _call(s.number),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTwo,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderGlass),
                        ),
                        child: Row(
                          children: [
                            Text(s.emoji, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 14),
                            Expanded(child: Text(s.name, style: AppTextStyles.subtitle)),
                            Text(
                              s.number,
                              style: AppTextStyles.title.copyWith(color: AppColors.sosRed),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.phone, color: AppColors.confirmedGreen, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(sosProvider.notifier).retry();
                    context.go(Routes.home);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sosRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                  child: Text('Try Again', style: AppTextStyles.buttonLabel),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(sosProvider.notifier).reset();
                  context.go(Routes.home);
                },
                child: Text('Go Home', style: AppTextStyles.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
