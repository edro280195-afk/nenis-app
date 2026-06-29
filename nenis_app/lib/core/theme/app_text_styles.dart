import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display = GoogleFonts.poppins(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.12,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );

  static TextStyle h1 = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static TextStyle h2 = GoogleFonts.poppins(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.ink,
  );

  static TextStyle subtitle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.ink2,
  );

  static TextStyle body = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  static TextStyle button = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
  );

  static TextStyle buttonSmall = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
  );

  static TextStyle chip = GoogleFonts.poppins(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  static TextStyle nav = GoogleFonts.poppins(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink3,
  );

  static TextStyle input = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  static TextStyle fieldPlaceholder = GoogleFonts.poppins(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    color: AppColors.ink3,
  );

  static TextStyle eyebrow(Color color) => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: color,
      );

  static TextTheme toTextTheme() {
    return GoogleFonts.poppinsTextTheme().apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
  }
}
