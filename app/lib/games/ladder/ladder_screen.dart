import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
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
                        child: CandyButton(
                          label: '',
                          height: 50,
                          depth: 5,
                          radius: 10,
                          candy: k == '⌫' ? Candy.orange : Candy.white,
                          sound: Sfx.tap,
                          onTap: () => _key(k),
                          leading: k == '⌫'
                              ? const Icon(Icons.backspace_rounded, color: Colors.white, size: 20)
                              : Text(k, style: AppText.display(20, color: AppColors.ink)),
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
    decoration: BoxDecoration(
      gradient: c.face,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.dark, width: 2),
    ),
    child: Text(text, style: AppText.display(15)),
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
              tween: Tween(begin: typing && word[i] != ' ' ? 0.5 : 1, end: 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: (prev != null && prev![i] != word[i]) ? Candy.pink.face : candy.face,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (prev != null && prev![i] != word[i]) ? Candy.pink.dark : candy.dark,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (prev != null && prev![i] != word[i]) ? Candy.pink.dark : candy.dark,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  word[i],
                  style: AppText.display(
                    30,
                    color: candy == Candy.white && !(prev != null && prev![i] != word[i])
                        ? AppColors.ink
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({this.dashed = false});
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final _ in [0, 1])
          Container(
            width: 6,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 46),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: dashed ? 0.25 : 0.55),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    ),
  );
}
