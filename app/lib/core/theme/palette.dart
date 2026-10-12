import 'package:flutter/material.dart';

/// Brand palette. Saturated "candy" colours with a darker shade used for the 3D lip
/// of buttons/tiles and a light shade for glossy highlights.
class Candy {
  const Candy(this.light, this.base, this.dark);
  final Color light;
  final Color base;
  final Color dark;

  LinearGradient get face => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, base],
      );

  static const pink = Candy(Color(0xFFFF8FB1), Color(0xFFFF3D7F), Color(0xFFB0124E));
  static const gold = Candy(Color(0xFFFFE680), Color(0xFFFFB800), Color(0xFFC27A00));
  static const blue = Candy(Color(0xFF7FDBFF), Color(0xFF2E8BFF), Color(0xFF1546B8));
  static const purple = Candy(Color(0xFFD3A6FF), Color(0xFF9B4DFF), Color(0xFF5B1DB8));
  static const green = Candy(Color(0xFF9CFFB0), Color(0xFF22D36B), Color(0xFF0E8A45));
  static const orange = Candy(Color(0xFFFFC18A), Color(0xFFFF7A1A), Color(0xFFC04A00));
  static const teal = Candy(Color(0xFF8CFFF0), Color(0xFF14C8C0), Color(0xFF087F80));
  static const red = Candy(Color(0xFFFF9A9A), Color(0xFFFF3B4E), Color(0xFFB0102A));
  static const grey = Candy(Color(0xFFE6E2F2), Color(0xFFB7B0CF), Color(0xFF7A7196));
  static const white = Candy(Color(0xFFFFFFFF), Color(0xFFF4F0FF), Color(0xFFC9BEEB));
}

class AppColors {
  static const ink = Color(0xFF2A0F57);
  static const inkSoft = Color(0xFF5B4B86);
  static const night = Color(0xFF1A0838);
  static const deep = Color(0xFF2D0B6B);
  static const royal = Color(0xFF5A1FC4);
  static const sky = Color(0xFF3D7BFF);
  static const panel = Color(0xFFFFF9F0);
  static const panelEdge = Color(0xFFE9D8FF);
  static const gold = Color(0xFFFFC928);
  static const goldDeep = Color(0xFFE08A00);
  static const heart = Color(0xFFFF3B6B);
  static const gem = Color(0xFF34E0FF);
  static const success = Color(0xFF2BD66F);
  static const danger = Color(0xFFFF4757);

  /// Main world background — deep violet into electric blue.
  static const LinearGradient worldBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3A0CA3), Color(0xFF7209B7), Color(0xFFB5179E)],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient nightBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14052E), Color(0xFF2D0B6B), Color(0xFF4A148C)],
  );
}
