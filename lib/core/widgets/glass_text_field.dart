import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Shared dark-glassmorphism form field used across the auth screens.
class GlassTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? hint;
  final int maxLines;

  const GlassTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.hint,
    this.maxLines = 1,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTextStyles.caption,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceTwo,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(AppColors.borderGlass),
        enabledBorder: _border(AppColors.borderGlass),
        focusedBorder: _border(AppColors.infoBlue, 1.5),
        errorBorder: _border(AppColors.sosRed),
        focusedErrorBorder: _border(AppColors.sosRed, 1.5),
      ),
    );
  }
}
