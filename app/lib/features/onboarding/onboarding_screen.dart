import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  int _avatar = 0;
  final _name = TextEditingController();

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } else {
      final s = context.services;
      s.player.completeOnboarding(name: _name.text, avatar: _avatar);
      s.analytics.log('onboarding_complete', {'avatar': _avatar});
      s.api.updatePreferences({'displayName': s.player.data.displayName, 'avatarId': _avatar}).catchError((Object _) {});
      Audio.instance.fx(Sfx.unlock, HapticKind.heavy);
      // First session goes straight into a quick, satisfying first level.
      context.go('/');
      context.push('/play/level/1');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: CandyBackground(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _page == 2 ? null : () => _pages.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.easeOut),
                child: Text(_page == 2 ? '' : 'Skip', style: AppText.body(16, color: Colors.white70)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  const _Welcome(),
                  const _Games(),
                  _Pal(
                    avatar: _avatar,
                    name: _name,
                    onAvatar: (i) => setState(() => _avatar = i),
                  ),
                ],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 26 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.gold : Colors.white38,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: CandyButton(
                label: _page == 2 ? "Let's play!" : 'Next',
                candy: _page == 2 ? Candy.green : Candy.pink,
                height: 68,
                pulse: true,
                onTap: _next,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Welcome extends StatefulWidget {
  const _Welcome();
  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        height: 250,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value * 2 * math.pi;
            return Stack(alignment: Alignment.center, children: [
              for (var i = 0; i < GameType.values.length; i++)
                Transform.translate(
                  offset: Offset(math.cos(t * 0.5 + i * 2 * math.pi / 5) * 105, math.sin(t * 0.5 + i * 2 * math.pi / 5) * 70 + math.sin(t + i) * 6),
                  child: Transform.rotate(angle: math.sin(t + i) * 0.18, child: GameBadge(game: GameType.values[i], size: 66)),
                ),
              Transform.scale(scale: 1 + math.sin(t * 2) * 0.03, child: const _Logo()),
            ]);
          },
        ),
      ),
      const SizedBox(height: 24),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: OutlinedText('Five brain games.\nOne sweet habit.', size: 30),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Text('Fresh puzzles every day. A few minutes is all it takes to feel sharper.',
            textAlign: TextAlign.center, style: AppText.body(16, color: Colors.white.withValues(alpha: 0.85))),
      ),
    ]);
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => const Column(mainAxisSize: MainAxisSize.min, children: [
        OutlinedText('PUZZLE', size: 46, gradient: LinearGradient(colors: [Color(0xFFFFF59A), Color(0xFFFFB800)]), stroke: Color(0xFF7A2B00)),
        OutlinedText('HUB', size: 58, gradient: LinearGradient(colors: [Color(0xFFFF9BE2), Color(0xFFFF3D7F)]), stroke: Color(0xFF6B0636)),
      ]);
}

class _Games extends StatelessWidget {
  const _Games();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        const OutlinedText('Pick a puzzle,\nany puzzle', size: 32),
        const SizedBox(height: 16),
        for (var i = 0; i < GameType.values.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 120),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset(60 * (1 - v), 0), child: child)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                GameBadge(game: GameType.values[i], size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(GameType.values[i].title, style: AppText.display(20)),
                    Text(GameType.values[i].tagline, style: AppText.body(13, color: Colors.white70)),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Pal extends StatelessWidget {
  const _Pal({required this.avatar, required this.name, required this.onAvatar});
  final int avatar;
  final TextEditingController name;
  final ValueChanged<int> onAvatar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const OutlinedText('Meet your Puzzle Pal', size: 30),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          key: ValueKey(avatar),
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Avatar(index: avatar, size: 130, ring: true),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < Avatar.count; i++)
            Pressable(
              onTap: () => onAvatar(i),
              semanticLabel: 'Pal ${i + 1}',
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: avatar == i ? AppColors.gold : Colors.white24, width: 3),
                ),
                child: Avatar(index: i, size: 54),
              ),
            ),
        ]),
        const SizedBox(height: 20),
        TextField(
          controller: name,
          maxLength: 20,
          textAlign: TextAlign.center,
          style: AppText.display(24, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Your name',
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Text('No sign-up needed. You can change this any time.', style: AppText.body(13, color: Colors.white70)),
      ]),
    );
  }
}
