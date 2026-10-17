import 'package:flutter/material.dart';

/// Accent colours. Flat and confident: [base] is the fill, [dark] the pressed/edge
/// shade, [light] a soft tint for backgrounds behind the accent.
///
/// (The name is historical; the look is flat, not glossy.)
class Candy {
  const Candy(this.light, this.base, this.dark);
  final Color light;
  final Color base;
  final Color dark;

  /// Solid fill kept as a gradient so existing decorations keep working.
  LinearGradient get face => LinearGradient(colors: [base, base]);

  /// Text/icon colour that reads on [base].
  Color get on => (this == white || this == grey || this == gold) ? AppColors.ink : const Color(0xFFFFFDF8);

  static const pink = Candy(Color(0xFFFBE7EC), Color(0xFFD9577E), Color(0xFFB03F62));
  static const gold = Candy(Color(0xFFFBF0D6), Color(0xFFE9B23D), Color(0xFFC08E22)); // mustard
  static const blue = Candy(Color(0xFFE4EAFA), Color(0xFF2D5BD3), Color(0xFF1F44A6)); // cobalt
  static const purple = Candy(Color(0xFFF0E8F5), Color(0xFF8E5BA8), Color(0xFF6E4285)); // plum
  static const green = Candy(Color(0xFFE5EFE6), Color(0xFF5E9468), Color(0xFF467350)); // sage
  static const orange = Candy(Color(0xFFFBE6DF), Color(0xFFE4572E), Color(0xFFB8401C)); // tomato
  static const teal = Candy(Color(0xFFDFEFEE), Color(0xFF2E8C88), Color(0xFF206866));
  static const red = Candy(Color(0xFFFBE3E1), Color(0xFFD6423A), Color(0xFFAA2E27));
  static const grey = Candy(Color(0xFFEFEBE2), Color(0xFFE3DED2), Color(0xFFC9C2B3));
  static const white = Candy(Color(0xFFFFFFFF), Color(0xFFFFFDF8), Color(0xFFE3DDCF));

  /// Ink: the primary action colour (black pills, like a newspaper's puzzle section).
  static const ink = Candy(Color(0xFFE8E3D8), Color(0xFF111111), Color(0xFF000000));
}

class AppColors {
  // Surfaces.
  static const bg = Color(0xFFF4F1EA); // newsprint paper
  static const surface = Color(0xFFFFFDF8);
  static const border = Color(0xFFE3DDCF);
  static const divider = Color(0xFFE8E3D8);

  // Text.
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF5E5A52);
  static const inkFaint = Color(0xFF9C968A);

  // Brand.
  static const primary = Color(0xFF111111);
  static const royal = primary;
  static const sky = Color(0xFF2D5BD3);
  static const accent = Color(0xFFE9B23D); // mustard

  /// Dark surfaces (snackbars, dark chips).
  static const night = Color(0xFF111111);
  static const deep = Color(0xFF2A2824);

  // Legacy surface names, now mapped onto the editorial palette.
  static const panel = surface;
  static const panelEdge = border;

  // Semantic.
  static const gold = Color(0xFFE9B23D);
  static const goldDeep = Color(0xFFC08E22);
  static const heart = Color(0xFFD6423A);
  static const gem = Color(0xFF2D5BD3);
  static const success = Color(0xFF467350);
  static const danger = Color(0xFFD6423A);

  /// Soft, warm elevation for cards.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x14403A2E), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0D403A2E), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// App background (kept as gradients for API compatibility; both are flat paper).
  static const LinearGradient worldBg = LinearGradient(colors: [bg, bg]);
  static const LinearGradient nightBg = LinearGradient(colors: [bg, bg]);
}
