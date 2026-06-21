import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography for ResQPK. Inter for Latin, Noto Nastaliq Urdu for Urdu.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get display =>
      GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  static TextStyle get title =>
      GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  static TextStyle get subtitle =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary);

  static TextStyle get caption =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);

  static TextStyle get buttonLabel =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);

  // Apply with Directionality(textDirection: TextDirection.rtl, ...) at the widget level.
  static TextStyle get urdu =>
      GoogleFonts.notoNastaliqUrdu(fontSize: 16, color: AppColors.textPrimary);
}
