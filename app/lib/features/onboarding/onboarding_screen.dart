import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../home/home_screen.dart';
import '../splash/splash_screen.dart' show QuintileMark;

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
      unawaited(s.pushProfile());
      Audio.instance.fx(Sfx.unlock, HapticKind.heavy);
      // Land on the Home dashboard; the player chooses what to play first.
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: CandyBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _page == 2
                      ? null
                      : () =>
                            _pages.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.easeOut),
                  child: Text(
                    _page == 2 ? '' : 'Skip',
                    style: AppText.body(15, color: AppColors.inkSoft, weight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (p) => setState(() => _page = p),
                  children: [
                    const _Welcome(),
                    const _Games(),
                    _Pal(avatar: _avatar, name: _name, onAvatar: (i) => setState(() => _avatar = i)),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: CandyButton(
                  label: _page == 2 ? "Let's play" : 'Continue',
                  candy: Candy.ink,
                  height: 56,
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _Logo(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < GameType.values.length; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 350 + i * 90),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: GameBadge(game: GameType.values[i], size: 52),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 40),
          Text('Five brain games.\nOne daily habit.', textAlign: TextAlign.center, style: AppText.display(30)),
          const SizedBox(height: 12),
          Text(
            'Fresh puzzles every day. A few minutes is all it takes to feel sharper.',
            textAlign: TextAlign.center,
            style: AppText.body(16, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(dimension: 84, child: CustomPaint(painter: QuintileMark(1))),
      const SizedBox(height: 16),
      Text('Quintile', style: AppText.display(34)),
    ],
  );
}

class _Games extends StatelessWidget {
  const _Games();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        Text('THE GAMES', style: AppText.label(11)),
        const SizedBox(height: 4),
        Text('Pick a puzzle,\nany puzzle', style: AppText.display(30)),
        const SizedBox(height: 24),
        for (var i = 0; i < GameType.values.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 120),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Opacity(
              opacity: v.clamp(0, 1),
              child: Transform.translate(offset: Offset(24 * (1 - v), 0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    GameBadge(game: GameType.values[i], size: 48),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(GameType.values[i].title, style: AppText.display(16)),
                          const SizedBox(height: 2),
                          Text(GameType.values[i].tagline, style: AppText.body(13, color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('YOUR PROFILE', style: AppText.label(11)),
          const SizedBox(height: 4),
          Text('Meet your Puzzle Pal', textAlign: TextAlign.center, style: AppText.display(30)),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            key: ValueKey(avatar),
            tween: Tween(begin: 0.9, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Avatar(index: avatar, size: 112, ring: true),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < Avatar.count; i++)
                Pressable(
                  onTap: () => onAvatar(i),
                  semanticLabel: 'Pal ${i + 1}',
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: avatar == i ? AppColors.primary : AppColors.border,
                        width: avatar == i ? 2.5 : 1.5,
                      ),
                    ),
                    child: Avatar(index: i, size: 54),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            maxLength: 20,
            textAlign: TextAlign.center,
            style: AppText.display(20),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: 'Your name',
              hintStyle: AppText.display(20, color: AppColors.inkFaint),
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No sign-up needed. You can change this any time.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
