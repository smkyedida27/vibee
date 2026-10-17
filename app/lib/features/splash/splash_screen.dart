import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/outlined_text.dart';

/// Opening screen: the Quintile mark (a serif Q whose tail is a puzzle piece) settles in,
/// then the masthead and today's dateline. Self-contained: runs before app services exist.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _t(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) _c.value = 1;
    return CandyBackground(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: _t(0, 0.45, Curves.elasticOut),
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF172873), offset: Offset(0, 7)),
                      BoxShadow(color: Color(0x66172873), blurRadius: 24, offset: Offset(0, 12)),
                    ],
                  ),
                  child: CustomPaint(painter: QuintileMark(_c.value)),
                ),
              ),
              const SizedBox(height: 20),
              Transform.translate(
                offset: Offset(0, 20 * (1 - _t(0.3, 0.7, Curves.easeOutBack))),
                child: Opacity(
                  opacity: _t(0.3, 0.6),
                  child: const OutlinedText('Quintile', size: 58, stroke: Color(0xFF172873)),
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: _t(0.5, 0.8),
                child: const OutlinedText(
                  'Five puzzles · one daily streak',
                  size: 18,
                  stroke: Color(0xFF172873),
                  shadow: false,
                ),
              ),
              const SizedBox(height: 28),
              Opacity(
                opacity: _t(0.6, 0.9),
                child: Container(
                  width: 200,
                  height: 22,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xCC172873),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.15 + 0.85 * _t(0.55, 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: Candy.green.face, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Quintile mark: an ink tile with a paper serif "Q"; its tail is a mustard puzzle
/// piece that drops in and settles. [t] 0→1 animates the piece; 1 is the resting mark.
class QuintileMark extends CustomPainter {
  QuintileMark(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width;
    final tile = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(u * 0.23));
    canvas.drawRRect(tile, Paint()..color = AppColors.ink);
    canvas.save();
    canvas.clipRRect(tile);
    final tp = TextPainter(
      text: TextSpan(
        text: 'Q',
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: u * 0.68,
          height: 1,
          color: Colors.white,
          fontVariations: const [FontVariation('wght', 900), FontVariation('SOFT', 100), FontVariation('opsz', 144)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(u * 0.47 - tp.width / 2, u * 0.49 - tp.height / 2));
    canvas.restore();

    // The piece drops from above and lands with a small settle.
    final d = Curves.easeOutBack.transform(((t - 0.25) / 0.45).clamp(0.0, 1.0));
    if (d <= 0) return;
    final side = u * 0.21;
    canvas.save();
    canvas.translate(u * 0.70, u * 0.71 - (1 - d) * u * 0.6);
    canvas.rotate((-12 + (1 - d) * -40) * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        Radius.circular(side * 0.18),
      ),
      Paint()..color = Candy.gold.base,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant QuintileMark old) => old.t != t;
}
