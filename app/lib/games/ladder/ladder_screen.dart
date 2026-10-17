import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/celebrations.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/dialogs.dart';
import '../../services/content_repo.dart';
import '../../services/services.dart';
import '../common/game_flow.dart';
import 'ladder_logic.dart';

class LadderScreen extends StatefulWidget {
  const LadderScreen({super.key, required this.request, required this.puzzle});
  final PlayRequest request;
  final LadderPuzzle puzzle;

  @override
  State<LadderScreen> createState() => _LadderScreenState();
}

class _LadderScreenState extends State<LadderScreen> with GameFlow, SingleTickerProviderStateMixin {
  late final List<String> path = [widget.puzzle.start];
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late int maxSteps = widget.puzzle.par + 5;
  String _typed = '';
  final _scroll = ScrollController();

  @override
  PlayRequest get request => widget.request;

  LadderDictionary get dict => context.services.content.dictionary;
  int get steps => path.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startFlow());
  }

  @override
  void dispose() {
    _shake.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _key(String k) {
    if (finished) return;
    setState(() {
      if (k == '⌫') {
        if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
      } else if (_typed.length < 4) {
        _typed += k;
      }
    });
    if (_typed.length == 4) _submit();
  }

  Future<void> _submit() async {
    final w = _typed;
    final last = path.last;
    String? error;
    if (!LadderDictionary.oneApart(last, w)) {
      error = 'Change exactly one letter of $last';
    } else if (!dict.contains(w)) {
      error = '$w isn\'t in our word list';
    } else if (path.contains(w)) {
      error = 'Already used $w';
    }
    if (error != null) {
      Audio.instance.fx(Sfx.wrong, HapticKind.heavy);
      toast(context, error, icon: Icons.error_rounded);
      await _shake.forward(from: 0);
      if (mounted) setState(() => _typed = '');
      return;
    }
    Audio.instance.fx(w == widget.puzzle.target ? Sfx.success : Sfx.pop, HapticKind.medium);
    setState(() {
      path.add(w);
      _typed = '';
    });
    if (w != widget.puzzle.target && path.length >= 3) {
      PraiseOverlay.show(context, path.length >= 4 ? 'Climbing!' : 'Nice step!', color: Candy.purple.base);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    _check();
  }

  void _check() {
    if (path.last == widget.puzzle.target) {
      final par = widget.puzzle.par;
      finish(
        RoundResult(
          won: true,
          stars: steps <= par ? 3 : (steps <= par + 2 ? 2 : 1),
          submission: {'path': path},
          detail: steps <= par ? 'Par $par — perfect climb!' : 'Par $par • You took $steps steps',
        ),
      );
    } else if (steps >= maxSteps) {
      finish(
        RoundResult(won: false, stars: 0, submission: {'path': path}),
        onContinue: () => setState(() => maxSteps += 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    return GameScaffold(
      request: request,
      elapsed: elapsed,
      roundOver: finished,
      confetti: confetti,
      onHint: () async {
        if (finished) return;
        final route = dict.shortestPath(path.last, p.target, avoid: path.toSet());
        if (route == null || route.length < 2) {
          if (context.mounted) toast(context, 'No fresh route from here — try Undo first');
          return;
        }
        if (await requestHint()) {
          if (mounted) {
            setState(() => _typed = '');
            for (final ch in route[1].split('')) {
              _key(ch);
            }
          }
        }
      },
      status: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Chip('PAR ${p.par}', Candy.gold),
          const SizedBox(width: 8),
          _Chip('STEPS $steps / $maxSteps', steps > p.par ? Candy.orange : Candy.green),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
              children: [
                for (var i = 0; i < path.length; i++) ...[
                  _WordRow(
                    word: path[i],
                    prev: i == 0 ? null : path[i - 1],
                    candy: i == 0 ? Candy.purple : Candy.white,
                  ),
                  const _Rung(),
                ],
                AnimatedBuilder(
                  animation: _shake,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 12, 0),
                    child: child,
                  ),
                  child: _WordRow(word: _typed.padRight(4, ' '), candy: Candy.blue, typing: true),
                ),
                const _Rung(dashed: true),
                _WordRow(word: p.target, candy: Candy.gold),
              ],
            ),
          ),
        ],
      ),
      toolbar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM⌫'])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final k in row.split(''))
                    Flexible(
                      flex: k == '⌫' ? 15 : 10,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Pressable(
                          scale: 0.92,
                          sound: Sfx.tap,
                          semanticLabel: k == '⌫' ? 'Delete' : k,
                          onTap: () => _key(k),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: k == '⌫' ? const Color(0xFFEFEDE6) : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: k == '⌫'
                                ? const Icon(Icons.backspace_outlined, color: AppColors.ink, size: 20)
                                : Text(k, style: AppText.display(18, color: AppColors.ink)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              ToolButton(
                icon: Icons.undo_rounded,
                label: 'Undo step',
                onTap: path.length > 1 ? () => setState(() => path.removeLast()) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.c);
  final String text;
  final Candy c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: c.light, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: AppText.label(12, color: c.dark)),
  );
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.candy, this.prev, this.typing = false});
  final String word;
  final String? prev;
  final Candy candy;
  final bool typing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('$word$i$typing'),
              tween: Tween(begin: typing && word[i] != ' ' ? 0.8 : 1, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: _tile(i),
            ),
          ),
      ],
    );
  }

  Widget _tile(int i) {
    final changed = prev != null && prev![i] != word[i];
    final Color fill, edge, fg;
    var edgeWidth = 1.5;
    if (typing) {
      fill = AppColors.surface;
      edge = AppColors.primary;
      fg = AppColors.ink;
      edgeWidth = 2;
    } else if (changed) {
      fill = Candy.green.light;
      edge = Candy.green.base;
      fg = Candy.green.dark;
    } else if (candy == Candy.white) {
      fill = AppColors.surface;
      edge = AppColors.border;
      fg = AppColors.ink;
    } else {
      // Start and target words: soft accent tint.
      fill = candy.light;
      edge = candy.base.withValues(alpha: 0.5);
      fg = candy.dark;
    }
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: edge, width: edgeWidth),
      ),
      child: Text(word[i], style: AppText.display(26, color: fg)),
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({this.dashed = false});
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 16,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final _ in [0, 1])
          Container(
            width: 3,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 46),
            decoration: BoxDecoration(
              color: dashed ? AppColors.divider : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}
