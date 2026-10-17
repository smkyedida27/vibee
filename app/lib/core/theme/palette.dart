import 'package:flutter/material.dart';

/// Glossy candy accents (Royal Match / Candy Crush style): [light] is the specular top,
/// [base] the body, [dark] the 3D lip and outline.
class Candy {
  const Candy(this.light, this.base, this.dark);
  final Color light;
  final Color base;
  final Color dark;

  /// Jelly face: bright top into the body colour.
  LinearGradient get face =>
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, base]);

  /// Text/icon colour that reads on [base].
  Color get on => (this == white || this == grey) ? AppColors.ink : Colors.white;

  static const pink = Candy(Color(0xFFFF9CC2), Color(0xFFFF3F8E), Color(0xFFB8125A));
  static const gold = Candy(Color(0xFFFFE885), Color(0xFFFFC21A), Color(0xFFC77800));
  static const blue = Candy(Color(0xFF8FDBFF), Color(0xFF2D8CFF), Color(0xFF1349B8));
  static const purple = Candy(Color(0xFFD8B0FF), Color(0xFF9B4DFF), Color(0xFF5A1DB5));
  static const green = Candy(Color(0xFFA6F57A), Color(0xFF3CC61E), Color(0xFF16810C));
  static const orange = Candy(Color(0xFFFFC489), Color(0xFFFF7B1C), Color(0xFFC14A00));
  static const teal = Candy(Color(0xFF8CFFEF), Color(0xFF16C7BF), Color(0xFF07807E));
  static const red = Candy(Color(0xFFFF9C9C), Color(0xFFFF3B4E), Color(0xFFB0102A));
  static const grey = Candy(Color(0xFFF2EEF8), Color(0xFFC9C1DC), Color(0xFF8C82A8));
  static const white = Candy(Color(0xFFFFFFFF), Color(0xFFFFF6E3), Color(0xFFD9B98A));

  /// The royal navy used for secondary actions and the tab bar.
  static const ink = Candy(Color(0xFF6E8BE8), Color(0xFF2E4BB8), Color(0xFF172873));
}

class AppColors {
  // Surfaces: cream parchment panels with golden rims, over the illustrated world.
  static const bg = Color(0xFF7FCBFF); // sky, shown where no scene is painted
  static const surface = Color(0xFFFFF8EA);
  static const border = Color(0xFFF1D8A6);
  static const divider = Color(0xFFF0E1C2);

  // Text: deep navy reads warmer and more "game" than black.
  static const ink = Color(0xFF22306B);
  static const inkSoft = Color(0xFF55608F);
  static const inkFaint = Color(0xFF9AA0C0);

  // Brand.
  static const primary = Color(0xFF2E4BB8);
  static const royal = primary;
  static const sky = Color(0xFF2D8CFF);
  static const accent = Color(0xFFFFC21A);

  static const night = Color(0xFF172873);
  static const deep = Color(0xFF2E4BB8);

  static const panel = surface;
  static const panelEdge = border;

  // Semantic.
  static const gold = Color(0xFFFFC21A);
  static const goldDeep = Color(0xFFC77800);
  static const heart = Color(0xFFFF3B6B);
  static const gem = Color(0xFF39D2FF);
  static const success = Color(0xFF3CC61E);
  static const danger = Color(0xFFFF3B4E);

  static const List<BoxShadow> cardShadow = [BoxShadow(color: Color(0x40172873), blurRadius: 16, offset: Offset(0, 8))];

  /// Daytime sky (top → horizon).
  static const LinearGradient worldBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3A9CFF), Color(0xFF7FCBFF), Color(0xFFC9F0FF)],
    stops: [0, 0.55, 1],
  );

  /// Dusk sky for game screens: calmer so boards pop.
  static const LinearGradient nightBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2E4BB8), Color(0xFF4C7BEA), Color(0xFF8CC4FF)],
  );
}
