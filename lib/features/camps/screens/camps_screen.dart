import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../data/models/camp_model.dart';
import '../providers/camps_provider.dart';

class CampsScreen extends ConsumerWidget {
  const CampsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campsAsync = ref.watch(nearbyCampsProvider);
    final servingCache = ref.watch(campsServingCacheProvider).asData?.value ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Nearby Medical Camps', style: AppTextStyles.subtitle),
      ),
      body: RefreshIndicator(
        color: AppColors.sosRed,
        backgroundColor: AppColors.surfaceOne,
        onRefresh: () async => ref.refresh(nearbyCampsProvider.future),
        child: campsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.sosRed)),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 80),
              Icon(Icons.cloud_off, color: AppColors.textSecondary, size: 48),
              const SizedBox(height: 12),
              Text(
                'Could not load camps.\nPull down to try again.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          data: (camps) {
            if (camps.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.medical_services_outlined,
                      color: AppColors.textSecondary, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No medical camps running near you right now.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: camps.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.confirmedGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.confirmedGreen, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Free health services near you · within 25 km',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.confirmedGreen),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (servingCache) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Showing saved camps',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ],
                  );
                }
                return _CampCard(camp: camps[i - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _CampCard extends StatelessWidget {
  final CampModel camp;

  const _CampCard({required this.camp});

  @override
  Widget build(BuildContext context) {
    final services = camp.servicesOffered;
    final extra = services.length > 3 ? services.length - 3 : 0;

    return GestureDetector(
      onTap: () => context.push('${Routes.camps}/${camp.id}', extra: camp),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOne,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(camp.name, style: AppTextStyles.subtitle),
            if (camp.organizerName != null) ...[
              const SizedBox(height: 2),
              Text(camp.organizerName!, style: AppTextStyles.caption),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (camp.distanceText != null)
                  _chip(camp.distanceText!, AppColors.infoBlue),
                if (camp.daysRemaining != null)
                  _chip(
                    '${camp.daysRemaining} days left',
                    camp.isEndingSoon ? AppColors.warningAmber : AppColors.textSecondary,
                  ),
              ],
            ),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...services.take(3).map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTwo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(s, style: AppTextStyles.caption),
                        ),
                      ),
                  if (extra > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTwo,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('+$extra more', style: AppTextStyles.caption),
                    ),
                ],
              ),
            ],
            if (camp.address != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      camp.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
      );
}
