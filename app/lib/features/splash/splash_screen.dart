import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';

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

  static const _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  static const _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', //
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

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
    final now = DateTime.now();
    return ColoredBox(
      color: AppColors.bg,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.85 + 0.15 * _t(0, 0.4, Curves.easeOutBack),
                child: Opacity(
                  opacity: _t(0, 0.25),
                  child: SizedBox.square(dimension: 104, child: CustomPaint(painter: QuintileMark(_c.value))),
                ),
              ),
              const SizedBox(height: 22),
              Opacity(
                opacity: _t(0.35, 0.7),
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _t(0.35, 0.75))),
                  child: Text('Quintile', style: AppText.display(46)),
                ),
              ),
              const SizedBox(height: 14),
              Container(width: 120 * _t(0.5, 0.85), height: 1, color: AppColors.ink),
              const SizedBox(height: 14),
              Opacity(
                opacity: _t(0.6, 0.95),
                child: Column(
                  children: [
                    Text(
                      '${_days[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}',
                      style: AppText.label(12, color: AppColors.ink),
                    ),
                    const SizedBox(height: 6),
                    Text('Five puzzles. One daily ritual.', style: AppText.body(14, color: AppColors.inkSoft)),
                  ],
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
          color: AppColors.bg,
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
