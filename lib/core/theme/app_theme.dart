import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Playful, vibrant pastel color palette
  static const Color primaryBlue = Color(0xFF29B6F6);
  static const Color deepBlue = Color(0xFF0288D1);
  static const Color sunnyYellow = Color(0xFFFFCA28);
  static const Color amberOrange = Color(0xFFFFA000);
  static const Color candyCoral = Color(0xFFFF5252);
  static const Color mintGreen = Color(0xFF66BB6A);
  static const Color deepGreen = Color(0xFF388E3C);
  static const Color bubblePurple = Color(0xFFAB47BC);
  static const Color softPink = Color(0xFFF48FB1);
  static const Color lightBg = Color(0xFFF1F8FE);
  static const Color cloudWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF263238);

  static TextStyle get titleFont => GoogleFonts.bubblegumSans(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: darkText,
        letterSpacing: 0.5,
      );

  static TextStyle get headingFont => GoogleFonts.fredoka(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: darkText,
      );

  static TextStyle get bodyFont => GoogleFonts.fredoka(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: darkText,
      );

  static TextStyle get gameFont => GoogleFonts.bubblegumSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: sunnyYellow,
        surface: lightBg,
      ),
      textTheme: GoogleFonts.fredokaTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
