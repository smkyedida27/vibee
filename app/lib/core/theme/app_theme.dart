import 'package:flutter/material.dart';

import 'palette.dart';

/// Chunky display face for titles/numbers and a rounded body face.
class AppFonts {
  static const display = 'LilitaOne';
  static const body = 'Fredoka';
}

class AppText {
  static TextStyle display(double size, {Color color = Colors.white, double height = 1.05}) =>
      TextStyle(fontFamily: AppFonts.display, fontSize: size, color: color, height: height, letterSpacing: 0.4);

  static TextStyle body(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w600}) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    color: color,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', _w(weight))],
  );

  static double _w(FontWeight w) => w.value.toDouble();
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppFonts.body,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.royal, primary: AppColors.royal),
    scaffoldBackgroundColor: AppColors.deep,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: AppFonts.body, bodyColor: AppColors.ink, displayColor: AppColors.ink),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()}),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.night,
      contentTextStyle: AppText.body(15, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
