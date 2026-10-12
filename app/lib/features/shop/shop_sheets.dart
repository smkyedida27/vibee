import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/outlined_text.dart';
import '../../services/api_client.dart';
import '../../services/services.dart';
import '../../state/player.dart';

/// "Out of lives" popup — the core soft paywall. Always offers a free path (wait/ad).
Future<void> showOutOfLives(BuildContext context, {bool browsing = false}) {
  return showCandyDialog<void>(
    context,
    title: browsing ? 'Lives' : 'Out of lives!',
    ribbon: Candy.red,
    builder: (ctx) => const _LivesBody(),
  );
}

class _LivesBody extends StatefulWidget {
  const _LivesBody();
  @override
  State<_LivesBody> createState() => _LivesBodyState();
}

class _LivesBodyState extends State<_LivesBody> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final p = context.player;
    final full = p.data.hearts >= Economy.maxHearts || p.unlimitedHearts;
    final next = p.nextHeartIn;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < Economy.maxHearts; i++)
          Opacity(opacity: i < p.data.hearts || p.unlimitedHearts ? 1 : 0.25, child: const GameArt(ArtKind.heart, size: 44)),
      ]),
      const SizedBox(height: 10),
      Text(
        p.unlimitedHearts
            ? 'Unlimited lives active — play all you like!'
            : full
                ? 'Your lives are full. Go crush some puzzles!'
                : 'Next life in ${next!.inMinutes}:${(next.inSeconds % 60).toString().padLeft(2, '0')}',
        textAlign: TextAlign.center,
        style: AppText.body(17, color: AppColors.inkSoft),
      ),
      if (!full) ...[
        const SizedBox(height: 16),
        CandyButton(
          label: 'Refill  •  ${Economy.heartRefillGems}',
          candy: Candy.green,
          height: 60,
          pulse: true,
          trailing: const GameArt(ArtKind.gem, size: 26),
          onTap: () async {
            final ok = await _spendGems(context, 'HEART_REFILL', Economy.heartRefillGems);
            if (ok) {
              s.player.refillHearts();
              Audio.instance.fx(Sfx.unlock, HapticKind.heavy);
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
        const SizedBox(height: 10),
        CandyButton(
          label: 'Watch ad  •  +1 life',
          icon: Icons.ondemand_video_rounded,
          candy: Candy.blue,
          height: 54,
          onTap: () async {
            if (await s.ads.showRewarded('life')) {
              s.player.addHeart();
              if (context.mounted) setState(() {});
            } else if (context.mounted) {
              toast(context, 'No ad available right now');
            }
          },
        ),
        const SizedBox(height: 10),
        CandyButton(
          label: 'Get VIP — unlimited lives',
          candy: Candy.gold,
          height: 54,
          trailing: const GameArt(ArtKind.crown, size: 26),
          onTap: () {
            Navigator.pop(context);
            context.go('/shop');
          },
        ),
      ],
    ]);
  }
}

/// Spends gems server-side when a session exists (server-authoritative), falling back
/// to local balance only when the account has never synced (pure guest offline).
Future<bool> _spendGems(BuildContext context, String sku, int cost) async {
  final s = context.services;
  if (s.player.data.gems < cost) {
    toast(context, 'Not enough gems — visit the Shop');
    return false;
  }
  if (s.api.hasSession) {
    try {
      final res = await s.api.spend(sku);
      final w = res['wallet'] as Map<String, dynamic>? ?? res;
      if (w['gems'] != null) s.player.setGems((w['gems'] as num).toInt());
      return true;
    } on ApiException catch (e) {
      if (!e.isOffline) {
        if (context.mounted) toast(context, e.message);
        return false;
      }
    }
  }
  return s.player.spendGems(cost);
}

/// Exposed for the shop screen.
Future<bool> spendGemsFor(BuildContext context, String sku, int cost) => _spendGems(context, sku, cost);

class ShopHeader extends StatelessWidget {
  const ShopHeader({super.key});
  @override
  Widget build(BuildContext context) => const OutlinedText('Candy Shop', size: 34);
}
