import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../games/common/game_type.dart';
import '../theme/app_theme.dart';

/// Illustrated, full-colour artwork for a game: the game's colour with a scene that hints
/// at how it plays (a Connect grid, a Crowns board, Sudoku digits, a ladder, merging tiles).
/// Drawn in code so it is crisp at every size and costs no assets.
class GameArtwork extends StatelessWidget {
  const GameArtwork({super.key, required this.game, this.radius = 20, this.compact = false, this.corner = false});
  final GameType game;
  final double radius;

  /// Fewer details for small tiles.
  final bool compact;

  /// Scene tucked into the top-right corner, leaving room for a label and title.
  final bool corner;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(painter: _CoverPainter(game, compact, corner), child: const SizedBox.expand()),
    );
  }
}

/// Small square game icon built from the artwork.
class GameBadge extends StatelessWidget {
  const GameBadge({super.key, required this.game, this.size = 56});
  final GameType game;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: GameArtwork(game: game, radius: size * 0.28, compact: true),
  );
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.game, this.compact, this.corner);
  final GameType game;
  final bool compact;
  final bool corner;

  /// Foreground for the scene: ink on light colours (mustard), paper on dark ones.
  Color get _white => game.candy.on;

  @override
  void paint(Canvas canvas, Size s) {
    final c = game.candy;
    final rect = Offset.zero & s;
    // Flat editorial colour block with one quiet tonal shape for depth.
    canvas.drawRect(rect, Paint()..color = c.base);
    canvas.drawCircle(
      Offset(s.width * 0.96, s.height * 0.04),
      s.shortestSide * 0.5,
      Paint()..color = Color.lerp(c.base, c.dark, 0.18)!,
    );

    // The scene sits in a square anchored right/centre.
    final side = corner ? s.shortestSide * 0.46 : (compact ? s.shortestSide * 0.62 : s.shortestSide * 0.66);
    final origin = corner
        ? Offset(s.width - side - s.shortestSide * 0.12, s.shortestSide * 0.12)
        : compact
        ? Offset((s.width - side) / 2, (s.height - side) / 2)
        : Offset(s.width - side - s.shortestSide * 0.12, (s.height - side) / 2);
    final box = origin & Size.square(side);
    switch (game) {
      case GameType.connect:
        _connect(canvas, box);
      case GameType.queens:
        _queens(canvas, box);
      case GameType.sudoku:
        _sudoku(canvas, box);
      case GameType.ladder:
        _ladder(canvas, box);
      case GameType.merge:
        _merge(canvas, box);
    }
  }

  RRect _rr(Rect r, double k) => RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * k));

  // 4x4 tiles; one row "solved" as a solid bar.
  void _connect(Canvas canvas, Rect b) {
    final n = compact ? 3 : 4;
    final gap = b.width * 0.06;
    final t = (b.width - gap * (n - 1)) / n;
    for (var r = 0; r < n; r++) {
      if (r == 0) {
        canvas.drawRRect(_rr(Rect.fromLTWH(b.left, b.top, b.width, t), 0.32), Paint()..color = _white);
        continue;
      }
      for (var col = 0; col < n; col++) {
        final selected = (r == 2 && col == 1) || (r == 1 && col == n - 1);
        canvas.drawRRect(
          _rr(Rect.fromLTWH(b.left + col * (t + gap), b.top + r * (t + gap), t, t), 0.26),
          Paint()..color = _white.withValues(alpha: selected ? 0.9 : 0.28),
        );
      }
    }
  }

  // Coloured-region board with crowns.
  void _queens(Canvas canvas, Rect b) {
    const n = 4;
    final cell = b.width / n;
    final board = _rr(b, 0.14);
    canvas.save();
    canvas.clipRRect(board);
    for (var r = 0; r < n; r++) {
      for (var col = 0; col < n; col++) {
        final a = ((r * 3 + col * 5) % 4) / 4;
        canvas.drawRect(
          Rect.fromLTWH(b.left + col * cell, b.top + r * cell, cell, cell),
          Paint()..color = _white.withValues(alpha: 0.18 + a * 0.22),
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b.width * 0.03
        ..color = _white.withValues(alpha: 0.85),
    );
    for (final (r, col) in compact ? [(1, 1)] : [(0, 1), (1, 3), (2, 0), (3, 2)]) {
      _crown(canvas, Rect.fromLTWH(b.left + col * cell, b.top + r * cell, cell, cell).deflate(cell * 0.2));
    }
  }

  void _crown(Canvas canvas, Rect r) {
    final p = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + r.height * 0.25)
      ..lineTo(r.left + r.width * 0.28, r.top + r.height * 0.55)
      ..lineTo(r.center.dx, r.top)
      ..lineTo(r.right - r.width * 0.28, r.top + r.height * 0.55)
      ..lineTo(r.right, r.top + r.height * 0.25)
      ..lineTo(r.right, r.bottom)
      ..close();
    canvas.drawPath(p, Paint()..color = _white);
  }

  // 3x3 grid with a few digits.
  void _sudoku(Canvas canvas, Rect b) {
    final board = _rr(b, 0.14);
    canvas.drawRRect(board, Paint()..color = _white.withValues(alpha: 0.95));
    final cell = b.width / 3;
    final line = Paint()
      ..color = game.candy.base.withValues(alpha: 0.35)
      ..strokeWidth = b.width * 0.02;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(b.left + i * cell, b.top), Offset(b.left + i * cell, b.bottom), line);
      canvas.drawLine(Offset(b.left, b.top + i * cell), Offset(b.right, b.top + i * cell), line);
    }
    const digits = {0: '5', 2: '3', 4: '7', 6: '9', 8: '1'};
    final shown = compact ? {4: '9'} : digits;
    shown.forEach((i, d) {
      final tp = TextPainter(
        text: TextSpan(
          text: d,
          style: AppText.display(cell * (compact ? 0.9 : 0.62), color: game.candy.dark),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = b.left + (i % 3 + 0.5) * cell, cy = b.top + (i ~/ 3 + 0.5) * cell;
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    });
  }

  // Rising word-tile rungs.
  void _ladder(Canvas canvas, Rect b) {
    final rows = compact ? 3 : 4;
    final h = b.height / (rows + (rows - 1) * 0.35);
    for (var i = 0; i < rows; i++) {
      final w = b.width * (0.55 + 0.15 * i);
      final y = b.bottom - (i + 1) * h - i * h * 0.35;
      final x = b.left + (b.width - w) * (i.isEven ? 0.15 : 0.85);
      final top = i == rows - 1;
      canvas.drawRRect(
        _rr(Rect.fromLTWH(x, y, w, h), 0.3),
        Paint()..color = _white.withValues(alpha: top ? 1 : 0.35 + 0.15 * i),
      );
      if (!compact) {
        for (var k = 0; k < 4; k++) {
          canvas.drawCircle(
            Offset(x + w * (0.2 + 0.2 * k), y + h / 2),
            h * 0.11,
            Paint()..color = top ? game.candy.base : _white.withValues(alpha: 0.7),
          );
        }
      }
    }
  }

  // Tiles merging up: 2, 4, 8 → 16.
  void _merge(Canvas canvas, Rect b) {
    final t = b.width * 0.44;
    final tiles = compact
        ? [(Offset(b.left, b.top + b.height * 0.3), '8', 0.4), (Offset(b.right - t, b.top), '16', 1.0)]
        : [
            (Offset(b.left, b.bottom - t), '2', 0.3),
            (Offset(b.right - t, b.bottom - t), '4', 0.45),
            (Offset(b.left, b.top), '8', 0.6),
            (Offset(b.right - t * 1.1, b.top - t * 0.05), '16', 1.0),
          ];
    for (final (o, label, a) in tiles) {
      final big = a == 1.0;
      final size = big ? t * 1.1 : t;
      final r = Rect.fromLTWH(o.dx, o.dy, size, size);
      canvas.drawRRect(_rr(r, 0.24), Paint()..color = _white.withValues(alpha: a));
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: AppText.display(size * (label.length > 1 ? 0.42 : 0.5), color: big ? game.candy.dark : Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));
    }
    if (!compact) {
      // Motion hint.
      final arrow = Paint()
        ..color = _white.withValues(alpha: 0.7)
        ..strokeWidth = b.width * 0.03
        ..strokeCap = StrokeCap.round;
      final a = Offset(b.left + t * 1.05, b.top + t * 0.5), z = Offset(b.right - t * 1.15, b.top + t * 0.5);
      canvas.drawLine(a, z, arrow);
      canvas.drawLine(z, z + Offset.fromDirection(math.pi * 0.8, t * 0.18), arrow);
      canvas.drawLine(z, z + Offset.fromDirection(-math.pi * 0.8, t * 0.18), arrow);
    }
  }

  @override
  bool shouldRepaint(covariant _CoverPainter old) => old.game != game || old.compact != compact || old.corner != corner;
}
