import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'candy_button.dart';

/// Full-screen "Level up!" moment: a burst of rays, the new level popping in, and a CTA.
Future<void> showLevelUp(BuildContext context, int level) {
  Audio.instance.fx(Sfx.unlock, HapticKind.heavy);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Level up',
    barrierColor: const Color(0xE616161D),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => _LevelUp(level: level),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(opacity: a, child: child),
  );
}

class _LevelUp extends StatefulWidget {
  const _LevelUp({required this.level});
  final int level;

  @override
  State<_LevelUp> createState() => _LevelUpState();
}

class _LevelUpState extends State<_LevelUp> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 14))
    ..repeat();

  @override
  void dispose() {
    _in.dispose();
    _spin.dispose();
    super.dispose();
  }

  double _t(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      c.transform(((_in.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _spin]),
        builder: (context, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _t(0.0, 0.3),
                child: Text('LEVEL UP', style: AppText.label(14, color: Candy.gold.base).copyWith(letterSpacing: 4)),
              ),
              const SizedBox(height: 18),
              SizedBox.square(
                dimension: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: _spin.value * 2 * math.pi,
                      child: Opacity(
                        opacity: _t(0.2, 0.6) * 0.9,
                        child: CustomPaint(size: const Size.square(240), painter: _Rays(Candy.gold.base)),
                      ),
                    ),
                    Transform.scale(
                      scale: _t(0.1, 0.65, Curves.elasticOut),
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 40)],
                        ),
                        alignment: Alignment.center,
                        child: Text('${widget.level}', style: AppText.display(60, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: _t(0.45, 0.8),
                child: Column(
                  children: [
                    Text('You reached level ${widget.level}!', style: AppText.display(26, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      'Sharper every day. Keep the streak going.',
                      style: AppText.body(15, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Opacity(
                opacity: _t(0.6, 1),
                child: CandyButton(
                  label: 'Awesome',
                  candy: Candy.gold,
                  width: 220,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rays extends CustomPainter {
  _Rays(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < 14; i++) {
      final a = i * 2 * math.pi / 14;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a - 0.09) * r, c.dy + math.sin(a - 0.09) * r)
          ..lineTo(c.dx + math.cos(a + 0.09) * r, c.dy + math.sin(a + 0.09) * r)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Rays old) => false;
}

/// Floating praise ("Great!", "Perfect!") that pops above the board and fades out.
/// Call [PraiseOverlay.show] from any game on a satisfying move.
class PraiseOverlay {
  static OverlayEntry? _current;

  static void show(BuildContext context, String text, {Color color = AppColors.primary}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Praise(
        text: text,
        color: color,
        onDone: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _Praise extends StatefulWidget {
  const _Praise({required this.text, required this.color, required this.onDone});
  final String text;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_Praise> createState() => _PraiseState();
}

class _PraiseState extends State<_Praise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final pop = Curves.elasticOut.transform((v / 0.45).clamp(0.0, 1.0));
          final fade = v < 0.7 ? 1.0 : 1 - (v - 0.7) / 0.3;
          return Align(
            alignment: const Alignment(0, -0.35),
            child: Transform.translate(
              offset: Offset(0, -24 * v),
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * pop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(widget.text, style: AppText.display(24, color: Colors.white)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
