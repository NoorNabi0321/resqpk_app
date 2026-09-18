import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Type scale for ResQPK — see ResQPK_Plan_3_Frontend_Design.md §3.
///
/// Sized for a phone held at arm's length, outdoors, by someone who is not calm.
/// Body text never goes below 15; captions never carry information you would
/// mind missing.
class ResqType {
  ResqType._();

  static TextStyle _inter(double size, double height, FontWeight weight, Color color) =>
      GoogleFonts.inter(
        fontSize: size,
        height: height / size, // Flutter's height is a multiplier
        fontWeight: weight,
        color: color,
      );

  static TextStyle display({Color color = Resq.ink}) => _inter(28, 34, FontWeight.w700, color);
  static TextStyle title({Color color = Resq.ink}) => _inter(22, 28, FontWeight.w700, color);
  static TextStyle section({Color color = Resq.ink}) => _inter(17, 24, FontWeight.w600, color);
  static TextStyle body({Color color = Resq.ink}) => _inter(15, 22, FontWeight.w400, color);
  static TextStyle bodyStrong({Color color = Resq.ink}) => _inter(15, 22, FontWeight.w600, color);
  static TextStyle caption({Color color = Resq.inkMuted}) => _inter(13, 18, FontWeight.w400, color);
  static TextStyle micro({Color color = Resq.inkFaint}) => _inter(11, 16, FontWeight.w500, color);
  static TextStyle button({Color color = Colors.white}) => _inter(16, 20, FontWeight.w600, color);

  /// Urdu and Sindhi. Nastaliq needs far more leading than Latin type — at
  /// normal line height the descenders of one line cut into the next.
  static TextStyle nastaliq({double size = 16, Color color = Resq.ink}) => GoogleFonts.notoNastaliqUrdu(
        fontSize: size,
        height: 1.8,
        color: color,
      );
}
