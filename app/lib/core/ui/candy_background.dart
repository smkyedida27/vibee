import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Screen backdrop: calm, flat paper. Static (no animated layers), which also keeps
/// scrolling and transitions smooth on low-end phones.
///
/// [orbColors] and [density] are accepted for compatibility and ignored.
class CandyBackground extends StatelessWidget {
  const CandyBackground({
    super.key,
    required this.child,
    this.gradient = AppColors.worldBg,
    this.orbColors = const [],
    this.density = 0,
  });

  final Widget child;
  final Gradient gradient;
  final List<Color> orbColors;
  final int density;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: gradient),
    child: child,
  );
}
