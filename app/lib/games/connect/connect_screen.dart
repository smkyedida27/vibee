import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/outlined_text.dart';
import '../../services/content_repo.dart';
import '../common/game_flow.dart';
import 'connect_logic.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.request, required this.puzzle});
  final PlayRequest request;
  final ConnectPuzzle puzzle;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> with GameFlow, TickerProviderStateMixin {
  late ConnectGame game = ConnectGame(widget.puzzle);
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  bool _busy = false;
  String? _hintWord;

  static const levelCandies = [Candy.gold, Candy.green, Candy.blue, Candy.purple];

  @override
  PlayRequest get request => widget.request;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startFlow());
  }

  @override
  void dispose() {
    _wave.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || game.selected.length != 4) return;
    _busy = true;
    await _wave.forward(from: 0);
    final outcome = game.submit();
    switch (outcome) {
      case GuessOutcome.correct:
        Audio.instance.fx(Sfx.success, HapticKind.medium);
      case GuessOutcome.oneAway:
        Audio.instance.fx(Sfx.wrong, HapticKind.heavy);
        if (mounted) toast(context, 'One away…', icon: Icons.near_me_rounded);
        await _shake.forward(from: 0);
      case GuessOutcome.wrong:
        Audio.instance.fx(Sfx.wrong, HapticKind.heavy);
        await _shake.forward(from: 0);
      case GuessOutcome.duplicate:
        if (mounted) toast(context, 'Already guessed!');
    }
    _busy = false;
    if (!mounted) return;
    setState(() {});
    if (game.isWon) {
      final m = game.mistakes;
      finish(RoundResult(
        won: true,
        stars: m == 0 ? 3 : (m <= 2 ? 2 : 1),
        mistakes: m,
        submission: {'guesses': game.guesses},
        detail: m == 0 ? 'Perfect — no mistakes!' : '$m mistake${m == 1 ? '' : 's'}',
      ));
    } else if (game.isLost) {
      finish(
        RoundResult(won: false, stars: 0, submission: {'guesses': game.guesses}, mistakes: game.mistakes),
        onContinue: _continue,
      );
    }
  }

  /// A continue rewinds the reveal and grants one more guess.
  void _continue() {
    final fresh = ConnectGame(widget.puzzle);
    for (final g in game.guesses) {
      fresh.selected
        ..clear()
        ..addAll(g);
      fresh.submit();
      if (fresh.isLost) break;
    }
    fresh.mistakes = ConnectGame.maxMistakes - 1;
    // Undo the auto-reveal of unsolved groups.
    final solvedByPlayer = fresh.solved.where((s) => game.guesses.any((g) => (g.toSet()..removeAll(s.words)).isEmpty)).toList();
    fresh.solved
      ..clear()
      ..addAll(solvedByPlayer);
    fresh.remaining
      ..clear()
      ..addAll(widget.puzzle.words.where((w) => !solvedByPlayer.any((s) => s.words.contains(w))));
    fresh.selected.clear();
    setState(() => game = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final selected = game.selected.toList();
    return GameScaffold(
      request: request,
      elapsed: elapsed,
      confetti: confetti,
      onHint: () async {
        if (await requestHint()) {
          final h = game.hint();
          if (h != null && context.mounted) {
            setState(() => _hintWord = h.$2);
            toast(context, 'One group is “${h.$1.title}” — it includes ${h.$2}', icon: Icons.lightbulb_rounded);
          }
        }
      },
      status: Column(children: [
        Text('Create four groups of four!', style: AppText.body(16, color: Colors.white)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Mistakes left', style: AppText.body(14, color: Colors.white70)),
          const SizedBox(width: 8),
          for (var i = 0; i < ConnectGame.maxMistakes; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < ConnectGame.maxMistakes - game.mistakes ? Colors.white : Colors.white24,
              ),
            ),
        ]),
      ]),
      body: LayoutBuilder(builder: (context, box) {
        final width = math.min(box.maxWidth, 520.0) - 24;
        final tileW = (width - 3 * 8) / 4;
        final tileH = math.min(tileW * 0.82, (box.maxHeight - 24 - game.solved.length * 8) / 4 - 8);
        return Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final g in game.solved) _SolvedBar(group: g, candy: levelCandies[g.level.clamp(0, 3)], height: tileH),
                  AnimatedBuilder(
                    animation: Listenable.merge([_wave, _shake]),
                    builder: (context, _) {
                      final shakeX = math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 10;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in game.remaining)
                            _wordTile(w, tileW, tileH, selected, shakeX),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      toolbar: Row(children: [
        ToolButton(
          icon: Icons.shuffle_rounded,
          label: 'Shuffle',
          onTap: () => setState(game.shuffle),
        ),
        ToolButton(
          icon: Icons.deselect_rounded,
          label: 'Deselect',
          onTap: game.selected.isEmpty ? null : () => setState(game.deselectAll),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: CandyButton(
              label: 'Submit',
              candy: Candy.pink,
              height: 62,
              pulse: game.selected.length == 4,
              onTap: game.selected.length == 4 && !_busy ? _submit : null,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _wordTile(String w, double tileW, double tileH, List<String> selected, double shakeX) {
    final isSel = game.selected.contains(w);
    final order = selected.indexOf(w);
    // Staggered hop when submitting.
    var hop = 0.0;
    if (isSel && _wave.isAnimating) {
      final t = ((_wave.value - order * 0.12) / 0.5).clamp(0.0, 1.0);
      hop = -math.sin(t * math.pi) * 14;
    }
    final c = isSel ? Candy.purple : (w == _hintWord ? Candy.gold : Candy.white);
    return Transform.translate(
      offset: Offset(isSel ? shakeX : 0, hop),
      child: SizedBox(
        width: tileW,
        height: tileH,
        child: CandyButton(
          label: '',
          height: tileH,
          depth: 6,
          radius: 14,
          candy: c,
          sound: Sfx.select,
          onTap: game.isOver
              ? null
              : () => setState(() {
                    game.toggle(w);
                  }),
          leading: SizedBox(
            width: tileW - 10,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                w,
                style: AppText.display(17, color: isSel ? Colors.white : AppColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SolvedBar extends StatelessWidget {
  const _SolvedBar({required this.group, required this.candy, required this.height});
  final ConnectGroup group;
  final Candy candy;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        height: height - 4,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: candy.face,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: candy.dark, width: 2),
          boxShadow: [BoxShadow(color: candy.dark, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedText(group.title.toUpperCase(), size: 18, stroke: candy.dark, maxLines: 1),
            const SizedBox(height: 2),
            Text(group.words.join(', '), style: AppText.body(13, color: Colors.white, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
