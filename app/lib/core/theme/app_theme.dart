import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Chunky game display face for titles and numbers, rounded friendly body face.
class AppFonts {
  static const display = 'LilitaOne';
  static const body = 'Fredoka';
}

class AppText {
  static TextStyle display(double size, {Color color = AppColors.ink, double height = 1.1}) =>
      TextStyle(fontFamily: AppFonts.display, fontSize: size, color: color, height: height, letterSpacing: 0.3);

  static TextStyle body(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w600}) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    color: color,
    height: 1.3,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
  );

  /// Small tracked caption.
  static TextStyle label(double size, {Color color = AppColors.inkSoft}) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation('wght', 700)],
    letterSpacing: 1.0,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppFonts.body,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: const AppBarTheme(systemOverlayStyle: SystemUiOverlayStyle.light),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: AppFonts.body, bodyColor: AppColors.ink, displayColor: AppColors.ink),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.night,
      contentTextStyle: AppText.body(15, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerColor: AppColors.divider,
  );
}
