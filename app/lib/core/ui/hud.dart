import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/services.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'game_art.dart';
import 'pressable.dart';

/// White capsule with the currency icon, the amount and an optional "+".
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({super.key, required this.art, required this.text, this.onPlus, this.minWidth = 78, this.sub});
  final ArtKind art;
  final String text;
  final String? sub;
  final VoidCallback? onPlus;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPlus,
      scale: 0.95,
      semanticLabel: '$text ${art.name}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: BoxConstraints(minWidth: minWidth),
            height: 36,
            padding: EdgeInsets.only(left: 6, right: onPlus != null ? 6 : 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameArt(art, size: 22),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: AppText.display(15, height: 1.1)),
                    if (sub != null)
                      Text(
                        sub!,
                        style: AppText.body(9, color: AppColors.inkSoft, weight: FontWeight.w700),
                      ),
                  ],
                ),
                if (onPlus != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1EEFF)),
                    child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 16),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hearts with live regeneration countdown.
class HeartsPill extends StatefulWidget {
  const HeartsPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  State<HeartsPill> createState() => _HeartsPillState();
}

class _HeartsPillState extends State<HeartsPill> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final unlimited = p.unlimitedHearts;
    final next = p.nextHeartIn;
    final sub = unlimited ? null : (next == null ? 'FULL' : _fmt(next));
    return CurrencyPill(
      art: ArtKind.heart,
      text: unlimited ? '∞' : '${p.data.hearts}',
      sub: sub,
      onPlus: widget.onTap,
      minWidth: 70,
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Top bar used on the main tabs: avatar • hearts • coins • gems.
class TopHud extends StatelessWidget {
  const TopHud({super.key, this.onAvatar, this.onHearts, this.onCoins, this.onGems});
  final VoidCallback? onAvatar, onHearts, onCoins, onGems;

  @override
  Widget build(BuildContext context) {
    final d = context.player.data;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Pressable(
            onTap: onAvatar,
            semanticLabel: 'Profile',
            child: Avatar(index: d.avatar, size: 46, ring: true),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  HeartsPill(onTap: onHearts),
                  const SizedBox(width: 6),
                  CurrencyPill(art: ArtKind.coin, text: _short(d.coins), onPlus: onCoins),
                  const SizedBox(width: 6),
                  CurrencyPill(art: ArtKind.gem, text: _short(d.totalGems), onPlus: onGems),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(int n) => n >= 100000 ? '${(n / 1000).floor()}K' : n.toString();
}

/// Original, hand-drawn "Puzzle Pal" avatars — a squishy blob with a face.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.index, this.size = 48, this.ring = false});
  final int index;
  final double size;
  final bool ring;

  static const count = 8;
  static const _candies = [
    Candy.pink,
    Candy.blue,
    Candy.gold,
    Candy.green,
    Candy.purple,
    Candy.orange,
    Candy.teal,
    Candy.red,
  ];

  @override
  Widget build(BuildContext context) {
    final c = _candies[index % _candies.length];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? 3 : 0),
      decoration: ring
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            )
          : null,
      child: ClipOval(child: CustomPaint(painter: _AvatarPainter(c, index))),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.c, this.index);
  final Candy c;
  final int index;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, c.light],
        ).createShader(Offset.zero & s),
    );
    // Body blob.
    final body = Path()
      ..moveTo(w * 0.12, h * 1.05)
      ..cubicTo(w * 0.05, h * 0.45, w * 0.25, h * 0.2, w * 0.5, h * 0.2)
      ..cubicTo(w * 0.75, h * 0.2, w * 0.95, h * 0.45, w * 0.88, h * 1.05)
      ..close();
    canvas.drawPath(body, Paint()..shader = c.face.createShader(Offset.zero & s));
    canvas.drawOval(
      Rect.fromLTWH(w * 0.28, h * 0.27, w * 0.16, h * 0.08),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    // Variants: antenna / ears / crown tuft.
    final accent = Paint()..color = c.dark;
    switch (index % 4) {
      case 0:
        canvas.drawLine(
          Offset(w * 0.5, h * 0.21),
          Offset(w * 0.56, h * 0.06),
          Paint()
            ..color = c.dark
            ..strokeWidth = w * 0.04,
        );
        canvas.drawCircle(Offset(w * 0.57, h * 0.06), w * 0.06, Paint()..color = const Color(0xFFFFD233));
      case 1:
        canvas.drawCircle(Offset(w * 0.24, h * 0.27), w * 0.09, Paint()..color = c.base);
        canvas.drawCircle(Offset(w * 0.76, h * 0.27), w * 0.09, Paint()..color = c.base);
      case 2:
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(w * (0.42 + i * 0.08), h * 0.2), w * 0.05, accent);
        }
      default:
        canvas.drawArc(
          Rect.fromLTWH(w * 0.3, h * 0.08, w * 0.4, h * 0.3),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFFFF5FA2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.06,
        );
    }
    // Eyes.
    final eyeY = h * 0.52;
    for (final x in [0.38, 0.62]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * x, eyeY), width: w * 0.15, height: h * 0.19),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(Offset(w * x + w * 0.015, eyeY + h * 0.02), w * 0.045, Paint()..color = AppColors.ink);
      canvas.drawCircle(Offset(w * x + w * 0.03, eyeY - h * 0.005), w * 0.015, Paint()..color = Colors.white);
    }
    // Cheeks + smile.
    final cheek = Paint()..color = const Color(0x66FF5FA2);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.27, h * 0.66), width: w * 0.12, height: h * 0.06), cheek);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.73, h * 0.66), width: w * 0.12, height: h * 0.06), cheek);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.66), width: w * 0.2, height: h * 0.14),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.035,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.index != index;
}
