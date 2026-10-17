import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Flat vector art for the economy & reward icons (no bitmap assets).
enum ArtKind { coin, gem, heart, star, starEmpty, bulb, chest, crown, bolt }

class GameArt extends StatelessWidget {
  const GameArt(this.kind, {super.key, this.size = 28});
  final ArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ArtPainter(kind)),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind);
  final ArtKind kind;

  static const _goldShade = AppColors.goldDeep;
  static const _gemShade = Color(0xFF1C86CF);
  static const _gemLight = Color(0xFF7CCBFA);

  @override
  void paint(Canvas canvas, Size s) {
    switch (kind) {
      case ArtKind.coin:
        _coin(canvas, s);
      case ArtKind.gem:
        _gem(canvas, s);
      case ArtKind.heart:
        _heart(canvas, s);
      case ArtKind.star:
        _star(canvas, s, filled: true);
      case ArtKind.starEmpty:
        _star(canvas, s, filled: false);
      case ArtKind.bulb:
        _bulb(canvas, s);
      case ArtKind.chest:
        _chest(canvas, s);
      case ArtKind.crown:
        _crown(canvas, s);
      case ArtKind.bolt:
        _bolt(canvas, s);
    }
  }

  void _coin(Canvas c, Size s) {
    final r = s.width / 2;
    final ctr = Offset(r, r);
    c.drawCircle(ctr, r * 0.94, Paint()..color = AppColors.gold);
    c.drawCircle(
      ctr,
      r * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = _goldShade,
    );
  }

  void _gem(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final outline = Path()
      ..moveTo(w * 0.22, h * 0.12)
      ..lineTo(w * 0.78, h * 0.12)
      ..lineTo(w * 0.98, h * 0.38)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.02, h * 0.38)
      ..close();
    c.drawPath(outline, Paint()..color = AppColors.gem);
    // Crown facet (lighter) and pavilion right half (darker): one shade each way.
    c.drawPath(
      Path()
        ..moveTo(w * 0.22, h * 0.12)
        ..lineTo(w * 0.78, h * 0.12)
        ..lineTo(w * 0.5, h * 0.38)
        ..close(),
      Paint()..color = _gemLight,
    );
    c.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.38)
        ..lineTo(w * 0.98, h * 0.38)
        ..lineTo(w * 0.5, h * 0.95)
        ..close(),
      Paint()..color = _gemShade,
    );
  }

  Path _heartPath(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..cubicTo(w * -0.15, h * 0.48, w * 0.12, h * -0.08, w * 0.5, h * 0.26)
      ..cubicTo(w * 0.88, h * -0.08, w * 1.15, h * 0.48, w * 0.5, h * 0.92)
      ..close();
  }

  void _heart(Canvas c, Size s) {
    c.drawPath(_heartPath(s), Paint()..color = AppColors.heart);
  }

  void _star(Canvas c, Size s, {required bool filled}) {
    final r = s.width / 2;
    final ctr = Offset(r, r * 1.06);
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r * 0.98 : r * 0.5;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = ctr + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    final fill = Paint()
      ..color = filled ? AppColors.gold : AppColors.divider
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(path, fill);
    // Rounded corners: a thin stroke in the same colour softens the points.
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeJoin = StrokeJoin.round
        ..color = filled ? AppColors.gold : AppColors.border,
    );
  }

  void _bulb(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.34, Paint()..color = AppColors.gold);
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.33, h * 0.68, w * 0.34, h * 0.24),
      Radius.circular(w * 0.06),
    );
    c.drawRRect(base, Paint()..color = const Color(0xFF9A98A3));
    c.drawLine(
      Offset(w * 0.35, h * 0.8),
      Offset(w * 0.65, h * 0.8),
      Paint()
        ..color = const Color(0xFF6E6C76)
        ..strokeWidth = h * 0.04,
    );
  }

  void _chest(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.42, w * 0.88, h * 0.5),
      Radius.circular(w * 0.08),
    );
    final lid = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.06, h * 0.14, w * 0.88, h * 0.32),
      topLeft: Radius.circular(w * 0.3),
      topRight: Radius.circular(w * 0.3),
    );
    c.drawRRect(body, Paint()..color = const Color(0xFFB8682A));
    c.drawRRect(lid, Paint()..color = const Color(0xFFD27E3A));
    final band = Paint()..color = AppColors.gold;
    c.drawRect(Rect.fromLTWH(w * 0.06, h * 0.4, w * 0.88, h * 0.07), band);
    c.drawRect(Rect.fromLTWH(w * 0.2, h * 0.14, w * 0.08, h * 0.78), band);
    c.drawRect(Rect.fromLTWH(w * 0.72, h * 0.14, w * 0.08, h * 0.78), band);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.41, h * 0.38, w * 0.18, h * 0.22), Radius.circular(w * 0.04)),
      Paint()..color = _goldShade,
    );
  }

  void _crown(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w * 0.08, h * 0.3)
      ..lineTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w * 0.92, h * 0.3)
      ..lineTo(w * 0.84, h * 0.82)
      ..lineTo(w * 0.16, h * 0.82)
      ..close();
    c.drawPath(
      p,
      Paint()
        ..color = AppColors.gold
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawRect(Rect.fromLTWH(w * 0.16, h * 0.7, w * 0.68, h * 0.12), Paint()..color = _goldShade);
    for (final x in [0.08, 0.5, 0.92]) {
      c.drawCircle(Offset(w * x, h * (x == 0.5 ? 0.15 : 0.3)), w * 0.07, Paint()..color = AppColors.gold);
    }
  }

  void _bolt(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w * 0.58, h * 0.04)
      ..lineTo(w * 0.16, h * 0.56)
      ..lineTo(w * 0.46, h * 0.56)
      ..lineTo(w * 0.38, h * 0.96)
      ..lineTo(w * 0.84, h * 0.4)
      ..lineTo(w * 0.54, h * 0.4)
      ..close();
    c.drawPath(p, Paint()..color = AppColors.gold);
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.kind != kind;
}
