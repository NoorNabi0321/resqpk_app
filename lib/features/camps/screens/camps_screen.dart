import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../data/models/camp_model.dart';
import '../providers/camps_provider.dart';

class CampsScreen extends ConsumerWidget {
  const CampsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campsAsync = ref.watch(nearbyCampsProvider);
    final servingCache = ref.watch(campsServingCacheProvider).asData?.value ?? false;

    return Scaffold(
      backgroundColor: Resq.canvas,
      appBar: AppBar(
        backgroundColor: Resq.canvas,
        elevation: 0,
        title: Text('Nearby Medical Camps', style: ResqType.section()),
      ),
      body: Column(
        children: [
          const OfflineBanner(
            message: 'No internet. Camps shown are the ones saved on this phone.',
          ),
          Expanded(
            child: RefreshIndicator(
        color: Resq.brandInk,
        backgroundColor: Resq.surface,
        onRefresh: () async => ref.refresh(nearbyCampsProvider.future),
        child: campsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Resq.critical)),
          // Kept scrollable so pull-to-refresh still works on a failed load —
          // an error state you cannot retry from is a dead end.
          error: (e, _) => ListView(
            children: [
              SizedBox(
                height: 420,
                child: ErrorState(
                  illustration: AppAssets.stateOffline,
                  title: 'Could not load camps',
                  message: 'They need a connection the first time. Pull down to try again.',
                  onRetry: () => ref.invalidate(nearbyCampsProvider),
                ),
              ),
            ],
          ),
          data: (camps) {
            if (camps.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(
                    height: 420,
                    child: EmptyState(
                      illustration: AppAssets.stateNoCamps,
                      title: 'No camps near you this week',
                      message: 'Free camps are listed here while they are running, '
                          'within 25 km of where you are.',
                    ),
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
                          color: Resq.ready.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Resq.ready, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Free health services near you · within 25 km',
                                style: ResqType.caption()
                                    .copyWith(color: Resq.ready),
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
                          style: ResqType.caption(),
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
          ),
        ],
      ),
    );
  }
}

class _CampCard extends StatelessWidget {
  final CampModel camp;

  const _CampCard({required this.camp});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${Routes.camps}/${camp.id}', extra: camp),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Resq.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Resq.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(camp.name, style: ResqType.section()),
            // What the camp actually does, in its own words. The organiser
            // name used to sit here; the detail screen carries it, along with
            // the full service list this card no longer tries to print.
            if ((camp.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                camp.description!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ResqType.caption(color: Resq.inkSoft),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (camp.distanceText != null)
                  _chip(camp.distanceText!, Resq.info),
                if (camp.daysRemaining != null)
                  _chip(
                    '${camp.daysRemaining} days left',
                    camp.isEndingSoon ? Resq.decision : Resq.inkSoft,
                  ),
              ],
            ),
            if (camp.address != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: Resq.inkSoft),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      camp.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ResqType.caption(),
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
        child: Text(label, style: ResqType.caption().copyWith(color: color)),
      );
}
