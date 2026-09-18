import 'package:flutter/material.dart';

import '../theme/typography.dart';
import 'app_colors.dart';

/// Legacy type names, now backed by the shared scale in `core/theme/typography.dart`.
///
/// Kept so existing screens compile; new work should use `ResqType`. Colours
/// here default to the dark ramp because these styles were written for the
/// driver screens — pass a colour explicitly on light surfaces, or use
/// `ResqType` which defaults to the light ramp.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get display => ResqType.display(color: AppColors.textPrimary);
  static TextStyle get title => ResqType.title(color: AppColors.textPrimary);
  static TextStyle get subtitle => ResqType.section(color: AppColors.textPrimary);
  static TextStyle get body => ResqType.body(color: AppColors.textPrimary);
  static TextStyle get caption => ResqType.caption(color: AppColors.textSecondary);
  static TextStyle get buttonLabel => ResqType.button();

  /// Apply with `Directionality(textDirection: TextDirection.rtl, ...)`.
  static TextStyle get urdu => ResqType.nastaliq(color: AppColors.textPrimary);
}
