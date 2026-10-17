import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < Economy.maxHearts; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: i < p.data.hearts || p.unlimitedHearts ? 1 : 0.18,
                  child: const GameArt(ArtKind.heart, size: 40),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          p.unlimitedHearts
              ? 'Unlimited lives active — play all you like!'
              : full
              ? 'Your lives are full. Go crush some puzzles!'
              : 'Next life in ${next!.inMinutes}:${(next.inSeconds % 60).toString().padLeft(2, '0')}',
          textAlign: TextAlign.center,
          style: AppText.body(16, color: AppColors.inkSoft, weight: FontWeight.w600),
        ),
        if (!full) ...[
          const SizedBox(height: 16),
          CandyButton(
            label: 'Refill  •  ${Economy.heartRefillGems}',
            candy: Candy.ink,
            height: 56,
            pulse: true,
            trailing: const GameArt(ArtKind.gem, size: 22),
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
            candy: Candy.white,
            height: 52,
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
            height: 52,
            trailing: const GameArt(ArtKind.crown, size: 22),
            onTap: () {
              Navigator.pop(context);
              context.go('/shop');
            },
          ),
        ],
      ],
    );
  }
}

/// One idempotency key per sku until the server gives a definitive answer, so a retry after a
/// timeout can never charge twice; and one spend per sku at a time (double taps).
final _pendingSpendKeys = <String, String>{};
final _spendsInFlight = <String>{};

/// Spends free (local) gems first and covers any shortfall with purchased gems through the
/// server wallet, which is the only authority for them (docs/CONTRACT.md §6).
Future<bool> _spendGems(BuildContext context, String sku, int cost) async {
  final s = context.services;
  final d = s.player.data;
  if (d.gems >= cost) return s.player.spendGems(cost);
  if (d.totalGems < cost) {
    toast(context, 'Not enough gems — visit the Shop');
    return false;
  }
  if (!_spendsInFlight.add(sku)) return false;
  final free = d.gems;
  final fromWallet = cost - free;
  final key = _pendingSpendKeys[sku] ??= s.api.newId();
  try {
    final res = await s.api.spend(sku, key: key, gems: fromWallet);
    _pendingSpendKeys.remove(sku);
    final w = res['wallet'] as Map<String, dynamic>? ?? res;
    if (w['gems'] != null) s.player.setPaidGems((w['gems'] as num).toInt());
    if (free > 0) s.player.spendGems(free.clamp(0, s.player.data.gems));
    return true;
  } on ApiException catch (e) {
    // Offline/timeout: the charge may or may not have landed; keep the key for the retry.
    if (!e.isOffline) _pendingSpendKeys.remove(sku);
    if (context.mounted) {
      toast(context, e.isOffline ? 'Connect to the internet to use purchased gems' : e.message);
    }
    if (e.code == 'INSUFFICIENT_FUNDS') unawaited(s.sync.refreshWallet());
    return false;
  } finally {
    _spendsInFlight.remove(sku);
  }
}

/// Exposed for the shop screen and results overlay.
Future<bool> spendGemsFor(BuildContext context, String sku, int cost) => _spendGems(context, sku, cost);

class ShopHeader extends StatelessWidget {
  const ShopHeader({super.key});
  @override
  Widget build(BuildContext context) => Text('Shop', style: AppText.display(30));
}
