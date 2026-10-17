import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Editorial voice: a soft serif for headlines (Fraunces, softness turned up so it feels
/// friendly) over a clean grotesque for everything else (Libre Franklin).
class AppFonts {
  static const display = 'Fraunces';
  static const body = 'Franklin';
}

class AppText {
  /// Headlines and numbers: heavy weight, tight tracking.
  static TextStyle display(double size, {Color color = AppColors.ink, double height = 1.12}) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: size,
    color: color,
    height: height,
    fontWeight: FontWeight.w800,
    fontVariations: [
      const FontVariation('wght', 780),
      const FontVariation('SOFT', 100),
      FontVariation('opsz', size.clamp(9, 144).toDouble()),
    ],
    letterSpacing: size >= 24 ? -0.5 : -0.1,
  );

  static TextStyle body(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    color: color,
    height: 1.35,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
  );

  /// Small caps-style label (e.g. "TODAY").
  static TextStyle label(double size, {Color color = AppColors.inkSoft}) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation('wght', 700)],
    letterSpacing: 1.1,
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
    appBarTheme: const AppBarTheme(systemOverlayStyle: SystemUiOverlayStyle.dark),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: AppFonts.body, bodyColor: AppColors.ink, displayColor: AppColors.ink),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.night,
      contentTextStyle: AppText.body(14, color: Colors.white, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: AppColors.divider,
  );
}
