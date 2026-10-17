import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// Headline text. Formerly a stroked "game" title; now clean heavy type.
/// [stroke], [strokeWidth] and [shadow] are accepted for compatibility and ignored.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 28,
    this.color = AppColors.ink,
    this.stroke = Colors.transparent,
    this.strokeWidth,
    this.shadow = false,
    this.textAlign = TextAlign.center,
    this.gradient,
    this.maxLines = 2,
  });

  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double? strokeWidth;
  final bool shadow;
  final TextAlign textAlign;
  final Gradient? gradient;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    Widget t = Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: AppText.display(size, color: color),
    );
    if (gradient != null) {
      t = ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (r) => gradient!.createShader(r), child: t);
    }
    return t;
  }
}
