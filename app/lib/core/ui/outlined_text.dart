import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Game-style text: bold fill, thick dark stroke and a drop shadow.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 28,
    this.color = Colors.white,
    this.stroke = const Color(0xFF3B0E7A),
    this.strokeWidth,
    this.shadow = true,
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
    final sw = strokeWidth ?? (size / 6.5).clamp(2.0, 9.0);
    final style = AppText.display(size);
    Widget fill = Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      style: style.copyWith(color: color),
    );
    if (gradient != null) {
      fill = ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (r) => gradient!.createShader(r), child: fill);
    }
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Stack(
        children: [
          if (shadow)
            Transform.translate(
              offset: Offset(0, size * 0.09),
              child: Text(
                text,
                textAlign: textAlign,
                maxLines: maxLines,
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = sw
                    ..strokeJoin = StrokeJoin.round
                    ..color = Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          Text(
            text,
            textAlign: textAlign,
            maxLines: maxLines,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw
                ..strokeJoin = StrokeJoin.round
                ..color = stroke,
            ),
          ),
          fill,
        ],
      ),
    );
  }
}
