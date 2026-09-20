import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The form field used across sign-in and registration.
///
/// Was a dark glass panel, from when the whole app was dark. Now a warm filled
/// field on the cream canvas — same name and API, so the auth screens did not
/// have to be rewritten to follow the palette.
class GlassTextField extends StatelessWidget {
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

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? hint;
  final int maxLines;

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Resq.radiusControl),
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
      style: ResqType.body(),
      cursorColor: Resq.brandInk,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: ResqType.body(color: Resq.inkFaint),
        labelStyle: ResqType.caption(color: Resq.inkSoft),
        floatingLabelStyle: ResqType.caption(color: Resq.brandInk),
        filled: true,
        fillColor: Resq.surface,
        suffixIcon: suffixIcon,
        // Generous vertical padding: these are tapped with a thumb, often by
        // someone standing outside a vehicle.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Resq.space4,
          vertical: Resq.space4,
        ),
        border: _border(Resq.border),
        enabledBorder: _border(Resq.border),
        focusedBorder: _border(Resq.brandInk, 1.5),
        errorBorder: _border(Resq.critical),
        focusedErrorBorder: _border(Resq.critical, 1.5),
        errorStyle: ResqType.caption(color: Resq.critical),
      ),
    );
  }
}
