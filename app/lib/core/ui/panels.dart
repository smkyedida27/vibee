import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'outlined_text.dart';

/// Cream "card" with a thick candy rim — the main content surface.
class CandyPanel extends StatelessWidget {
  const CandyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.rim = Candy.purple,
    this.radius = 26,
    this.color = AppColors.panel,
  });

  final Widget child;
  final EdgeInsets padding;
  final Candy rim;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + 5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [rim.light, rim.base, rim.dark],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, color],
          ),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

/// Frosted translucent surface for content sitting on top of the backdrop.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 22});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: 0.13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.06)],
        ),
      ),
      child: child,
    );
  }
}

/// Folded ribbon banner used as screen/popup titles.
class RibbonBanner extends StatelessWidget {
  const RibbonBanner(this.text, {super.key, this.candy = Candy.pink, this.fontSize = 30, this.width});
  final String text;
  final Candy candy;
  final double fontSize;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final h = fontSize * 1.9;
    return SizedBox(
      height: h + 10,
      width: width,
      child: CustomPaint(
        painter: _RibbonPainter(candy),
        child: Padding(
          padding: EdgeInsets.fromLTRB(h * 0.9, 2, h * 0.9, 12),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: OutlinedText(text, size: fontSize, stroke: candy.dark, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.c);
  final Candy c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height - 10;
    final tail = h * 0.55;
    final dark = Paint()..color = c.dark;
    // Tails.
    canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.25)
          ..lineTo(tail * 1.3, h * 0.25)
          ..lineTo(tail * 1.3, h + 8)
          ..lineTo(0, h + 8)
          ..lineTo(tail * 0.5, h * 0.62)
          ..close(),
        dark);
    canvas.drawPath(
        Path()
          ..moveTo(w, h * 0.25)
          ..lineTo(w - tail * 1.3, h * 0.25)
          ..lineTo(w - tail * 1.3, h + 8)
          ..lineTo(w, h + 8)
          ..lineTo(w - tail * 0.5, h * 0.62)
          ..close(),
        dark);
    // Body with slight arch.
    final body = Path()
      ..moveTo(tail * 0.8, 6)
      ..quadraticBezierTo(w / 2, -4, w - tail * 0.8, 6)
      ..lineTo(w - tail * 0.8, h)
      ..quadraticBezierTo(w / 2, h - 10, tail * 0.8, h)
      ..close();
    canvas.drawShadow(body, Colors.black, 6, false);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.light, c.base, c.base],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = c.dark);
    // Gloss strip.
    canvas.drawPath(
      Path()
        ..moveTo(tail * 1.0, 10)
        ..quadraticBezierTo(w / 2, 1, w - tail * 1.0, 10)
        ..lineTo(w - tail * 1.0, h * 0.36)
        ..quadraticBezierTo(w / 2, h * 0.26, tail * 1.0, h * 0.36)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) => old.c != c;
}

/// Section header used on scrolling screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          OutlinedText(text, size: 22, textAlign: TextAlign.left),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.royal, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 4)],
        Text(text, style: AppText.body(12, color: Colors.white, weight: FontWeight.w700)),
      ]),
    );
  }
}
