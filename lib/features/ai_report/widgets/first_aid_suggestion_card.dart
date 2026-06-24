import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Slides up on the TrackingScreen when the AI report's first-aid guidance
/// is ready. Dismissible; links to the full report.
class FirstAidSuggestionCard extends StatelessWidget {
  const FirstAidSuggestionCard({
    super.key,
    required this.suggestion,
    required this.urgencyLevel,
    required this.onViewFullReport,
    required this.onDismiss,
  });

  final String suggestion;
  final String urgencyLevel;
  final VoidCallback onViewFullReport;
  final VoidCallback onDismiss;

  Color get _urgencyColor {
    switch (urgencyLevel) {
      case 'critical':
        return AppColors.sosRed;
      case 'moderate':
        return const Color(0xFFF59E0B);
      case 'low':
        return AppColors.confirmedGreen;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _urgencyColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _urgencyColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _urgencyColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  urgencyLevel.toUpperCase(),
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('First Aid Guidance',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              suggestion,
              style: AppTextStyles.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onViewFullReport,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('View Full Report',
                style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.6, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 350.ms);
  }
}
