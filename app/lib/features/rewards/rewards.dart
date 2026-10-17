import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/confetti.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/outlined_text.dart';
import '../../services/services.dart';
import '../../state/player.dart';

// ------------------------------------------------------------------ login calendar
Future<void> showLoginCalendar(BuildContext context) {
  return showCandyDialog<void>(context, title: 'Daily Gifts', ribbon: Candy.gold, builder: (_) => const _Calendar());
}

class _Calendar extends StatefulWidget {
  const _Calendar();
  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  LoginReward? _claimed;

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final day = p.data.loginDay;
    final canClaim = p.canClaimLogin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Log in every day for bigger gifts!', style: AppText.body(15, color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < Economy.loginRewards.length; i++)
              _DayTile(
                day: i + 1,
                reward: Economy.loginRewards[i],
                claimed: i < day || (_claimed != null && i == day - 1),
                today: canClaim && i == day,
                big: i == Economy.loginRewards.length - 1,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_claimed != null)
          OutlinedText('Collected!', size: 26, stroke: Candy.green.dark)
        else
          CandyButton(
            label: canClaim ? 'Collect' : 'Come back tomorrow',
            candy: Candy.green,
            height: 60,
            pulse: canClaim,
            onTap: canClaim
                ? () {
                    final r = p.claimLogin();
                    Audio.instance.fx(Sfx.coin, HapticKind.heavy);
                    setState(() => _claimed = r);
                    context.services.sync.push();
                  }
                : null,
          ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.reward,
    required this.claimed,
    required this.today,
    required this.big,
  });
  final int day;
  final LoginReward reward;
  final bool claimed;
  final bool today;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final art = reward.gems > 0 ? ArtKind.gem : (reward.hints > 0 && reward.coins == 0 ? ArtKind.bulb : ArtKind.coin);
    final amount = reward.gems > 0 ? reward.gems : (reward.coins > 0 ? reward.coins : reward.hints);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: big ? 160 : 74,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: today
            ? Candy.gold.face
            : (claimed ? Candy.green.face : const LinearGradient(colors: [Color(0xFFF1EAFF), Color(0xFFE2D6FA)])),
        border: Border.all(
          color: today ? Candy.gold.dark : (claimed ? Candy.green.dark : AppColors.panelEdge),
          width: 2.5,
        ),
        boxShadow: today ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.7), blurRadius: 14)] : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'DAY $day',
                style: AppText.body(
                  11,
                  color: today || claimed ? Colors.white : AppColors.inkSoft,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              big ? const GameArt(ArtKind.chest, size: 40) : GameArt(art, size: 32),
              Text(
                big ? 'MEGA' : '×$amount',
                style: AppText.display(15, color: today || claimed ? Colors.white : AppColors.ink),
              ),
            ],
          ),
          if (claimed)
            const Positioned(right: 4, top: 4, child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ lucky spin
class SpinReward {
  const SpinReward(
    this.label,
    this.art,
    this.color, {
    this.coins = 0,
    this.gems = 0,
    this.hints = 0,
    this.lifeMinutes = 0,
    this.weight = 10,
  });
  final String label;
  final ArtKind art;
  final Color color;
  final int coins, gems, hints, lifeMinutes, weight;
}

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});
  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> with SingleTickerProviderStateMixin {
  static const rewards = [
    SpinReward('50', ArtKind.coin, Color(0xFFFF3D7F), coins: 50, weight: 22),
    SpinReward('2', ArtKind.bulb, Color(0xFFFFB800), hints: 2, weight: 12),
    SpinReward('100', ArtKind.coin, Color(0xFF2E8BFF), coins: 100, weight: 18),
    SpinReward('5', ArtKind.gem, Color(0xFF22D36B), gems: 5, weight: 10),
    SpinReward('250', ArtKind.coin, Color(0xFF9B4DFF), coins: 250, weight: 10),
    SpinReward('1h', ArtKind.heart, Color(0xFFFF7A1A), lifeMinutes: 60, weight: 8),
    SpinReward('1', ArtKind.bulb, Color(0xFF14C8C0), hints: 1, weight: 16),
    SpinReward('25', ArtKind.gem, Color(0xFFFF3B4E), gems: 25, weight: 4),
  ];

  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  final _confetti = ConfettiController();
  double _from = 0, _to = 0;
  bool _spinning = false;
  int? _won;
  int _lastTick = -1;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      // Tick sound as each segment passes the pointer.
      final angle = _angle;
      final seg = ((angle / (2 * math.pi)) * rewards.length).floor();
      if (seg != _lastTick) {
        _lastTick = seg;
        Audio.instance.play(Sfx.tap, volume: 0.4);
        Audio.instance.haptic(HapticKind.select);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _confetti.dispose();
    super.dispose();
  }

  double get _angle => _from + (_to - _from) * Curves.easeOutQuart.transform(_c.value);

  int _pick() {
    final total = rewards.fold(0, (a, r) => a + r.weight);
    var roll = math.Random.secure().nextInt(total);
    for (var i = 0; i < rewards.length; i++) {
      if (roll < rewards[i].weight) return i;
      roll -= rewards[i].weight;
    }
    return 0;
  }

  Future<void> _spin({required bool free}) async {
    if (_spinning) return;
    final s = context.services;
    if (!free) {
      final ok = await s.ads.showRewarded('spin');
      if (!ok) {
        if (mounted) toast(context, 'No video available right now');
        return;
      }
    } else {
      s.player.markFreeSpin();
    }
    final idx = _pick();
    final seg = 2 * math.pi / rewards.length;
    // Pointer is at the top; segment i is centred at i*seg.
    final target = 2 * math.pi * 6 + (2 * math.pi - idx * seg) + (math.Random().nextDouble() - 0.5) * seg * 0.6;
    setState(() {
      _spinning = true;
      _won = null;
      _from = _angle % (2 * math.pi);
      _to = target;
    });
    Audio.instance.play(Sfx.whoosh);
    await _c.forward(from: 0);
    final r = rewards[idx];
    final p = s.player;
    if (r.coins > 0) p.addCoins(r.coins);
    if (r.gems > 0) p.addGems(r.gems);
    if (r.hints > 0) p.addHints(r.hints);
    if (r.lifeMinutes > 0) p.grantUnlimitedHearts(Duration(minutes: r.lifeMinutes));
    Audio.instance.fx(Sfx.win, HapticKind.heavy);
    _confetti.burst(origin: const Offset(0.5, 0.4));
    s.sync.push();
    if (mounted) {
      setState(() {
        _spinning = false;
        _won = idx;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final r = _won == null ? null : rewards[_won!];
    return Scaffold(
      body: CandyBackground(
        gradient: AppColors.nightBg,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CandyIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.pop(),
                          size: 46,
                          semanticLabel: 'Back',
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const OutlinedText('Lucky Spin', size: 42),
                  Text('Spin once a day for free!', style: AppText.body(16, color: Colors.white70)),
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final size = math.min(box.maxWidth - 40, box.maxHeight - 20).clamp(200.0, 380.0);
                          return SizedBox(
                            width: size,
                            height: size + 30,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Positioned(
                                  top: 20,
                                  child: Transform.rotate(
                                    angle: _angle,
                                    child: SizedBox.square(
                                      dimension: size,
                                      child: CustomPaint(painter: _WheelPainter(rewards)),
                                    ),
                                  ),
                                ),
                                // Hub labels drawn unrotated would be wrong, so icons rotate with the wheel:
                                Positioned(
                                  top: 20,
                                  child: Transform.rotate(
                                    angle: _angle,
                                    child: SizedBox.square(
                                      dimension: size,
                                      child: Stack(
                                        children: [for (var i = 0; i < rewards.length; i++) _segmentLabel(i, size)],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(top: 20 + size / 2 - 34, child: const _Hub()),
                                const Positioned(top: 0, child: _Pointer()),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: r == null
                        ? const SizedBox(height: 40)
                        : Row(
                            key: ValueKey(_won),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const OutlinedText('You won', size: 26),
                              const SizedBox(width: 8),
                              GameArt(r.art, size: 36),
                              OutlinedText(r.lifeMinutes > 0 ? '∞ ${r.label}' : '×${r.label}', size: 26),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: p.canFreeSpin
                        ? CandyButton(
                            label: 'Spin!',
                            candy: Candy.green,
                            height: 68,
                            pulse: !_spinning,
                            onTap: _spinning ? null : () => _spin(free: true),
                          )
                        : CandyButton(
                            label: 'Spin again',
                            icon: Icons.ondemand_video_rounded,
                            candy: Candy.blue,
                            height: 64,
                            onTap: _spinning ? null : () => _spin(free: false),
                          ),
                  ),
                ],
              ),
            ),
            Positioned.fill(child: ConfettiLayer(controller: _confetti)),
          ],
        ),
      ),
    );
  }

  Widget _segmentLabel(int i, double size) {
    final seg = 2 * math.pi / rewards.length;
    final a = i * seg - math.pi / 2;
    final rad = size * 0.33;
    final c = Offset(size / 2 + math.cos(a) * rad, size / 2 + math.sin(a) * rad);
    return Positioned(
      left: c.dx - 30,
      top: c.dy - 30,
      width: 60,
      height: 60,
      child: Transform.rotate(
        angle: i * seg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameArt(rewards[i].art, size: 28),
            OutlinedText(rewards[i].label, size: 16, stroke: Colors.black.withValues(alpha: 0.6), shadow: false),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.rewards);
  final List<SpinReward> rewards;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFC21A));
    canvas.drawCircle(c, r - 4, Paint()..color = const Color(0xFFB86B00));
    final inner = r - 14;
    final seg = 2 * math.pi / rewards.length;
    for (var i = 0; i < rewards.length; i++) {
      final start = i * seg - math.pi / 2 - seg / 2;
      final rect = Rect.fromCircle(center: c, radius: inner);
      canvas.drawArc(
        rect,
        start,
        seg,
        true,
        Paint()
          ..shader = RadialGradient(colors: [Color.lerp(rewards[i].color, Colors.white, 0.35)!, rewards[i].color])
              .createShader(rect),
      );
      canvas.drawArc(
        rect,
        start,
        seg,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    // Bulbs around the rim.
    for (var i = 0; i < 24; i++) {
      final a = i * 2 * math.pi / 24;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (r - 7),
        4,
        Paint()..color = i.isEven ? Colors.white : const Color(0xFFFFF59A),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Hub extends StatelessWidget {
  const _Hub();
  @override
  Widget build(BuildContext context) => Container(
    width: 68,
    height: 68,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFFFF59A), Color(0xFFFFB800), Color(0xFFC27A00)],
      ),
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: const Center(child: GameArt(ArtKind.star, size: 36)),
  );
}

class _Pointer extends StatelessWidget {
  const _Pointer();
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(44, 52), painter: _PointerPainter());
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width / 2, s.height)
      ..lineTo(0, s.height * 0.3)
      ..arcToPoint(Offset(s.width, s.height * 0.3), radius: Radius.circular(s.width / 2))
      ..close();
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(path, Paint()..shader = Candy.red.face.createShader(Offset.zero & s));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.3), 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
