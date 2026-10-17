import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/panels.dart';
import '../../services/purchase_service.dart';
import '../../services/services.dart';
import '../../state/player.dart';
import 'shop_sheets.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  PurchaseService? _iap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final iap = context.services.purchases;
    if (_iap != iap) {
      _iap?.removeListener(_onIap);
      _iap = iap..addListener(_onIap);
    }
  }

  @override
  void dispose() {
    _iap?.removeListener(_onIap);
    super.dispose();
  }

  void _onIap() {
    if (!mounted) return;
    final iap = _iap!;
    switch (iap.state) {
      case PurchaseState.success:
        Audio.instance.fx(Sfx.win, HapticKind.heavy);
        toast(context, 'Purchase complete — enjoy!', icon: Icons.celebration_rounded);
      case PurchaseState.failed:
        toast(context, iap.lastError ?? 'Purchase failed', icon: Icons.error_rounded);
      case PurchaseState.unavailable:
        toast(context, 'Store unavailable on this device', icon: Icons.storefront_rounded);
      default:
        break;
    }
    iap.acknowledgeState();
    setState(() {});
  }

  void _buy(StoreItem item) => context.services.purchases.buy(item);

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final d = context.player.data;
    final iap = s.purchases;
    final busy = iap.state == PurchaseState.pending || iap.state == PurchaseState.verifying;
    final gemPacks = Catalog.items.where((i) => i.gems > 0).toList();
    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              TopHud(onHearts: () => showOutOfLives(context, browsing: true)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
                      child: Text('Shop', style: AppText.display(30)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                      child: Text('Gems, boosters and VIP', style: AppText.body(15, color: AppColors.inkSoft)),
                    ),
                    _VipCard(
                      active: d.isVip,
                      price: iap.priceOf(Catalog.byId('vip_monthly')),
                      onTap: d.isVip ? null : () => _buy(Catalog.byId('vip_monthly')),
                    ),
                    const SectionTitle('Gems'),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                      children: [
                        for (var i = 0; i < gemPacks.length; i++)
                          _GemPack(
                            item: gemPacks[i],
                            tier: i,
                            price: iap.priceOf(gemPacks[i]),
                            onTap: () => _buy(gemPacks[i]),
                          ),
                      ],
                    ),
                    const SectionTitle('Boosters'),
                    _OfferRow(
                      art: ArtKind.bulb,
                      title: '3 Hints',
                      subtitle: 'Crack any tricky puzzle',
                      cta: '${Economy.hintPackCoins}',
                      ctaArt: ArtKind.coin,
                      candy: Candy.gold,
                      onTap: () {
                        if (s.player.buyHintPack()) {
                          Audio.instance.fx(Sfx.coin, HapticKind.medium);
                          toast(context, '+3 hints!', icon: Icons.lightbulb_rounded);
                        } else {
                          toast(context, 'Not enough coins');
                        }
                      },
                    ),
                    _OfferRow(
                      art: ArtKind.heart,
                      title: 'Full Lives',
                      subtitle: 'Refill all ${Economy.maxHearts} lives now',
                      cta: '${Economy.heartRefillGems}',
                      ctaArt: ArtKind.gem,
                      candy: Candy.red,
                      onTap: () async {
                        if (await spendGemsFor(context, 'HEART_REFILL', Economy.heartRefillGems)) {
                          s.player.refillHearts();
                          if (context.mounted) toast(context, 'Lives refilled!', icon: Icons.favorite_rounded);
                        }
                      },
                    ),
                    _OfferRow(
                      art: ArtKind.coin,
                      title: '1,000 Coins',
                      subtitle: 'A sack of shiny coins',
                      cta: '25',
                      ctaArt: ArtKind.gem,
                      candy: Candy.orange,
                      onTap: () async {
                        if (await spendGemsFor(context, 'COINS_1000', 25)) {
                          s.player.addCoins(1000);
                          Audio.instance.fx(Sfx.coin, HapticKind.medium);
                        }
                      },
                    ),
                    _OfferRow(
                      art: ArtKind.bolt,
                      title: 'Free Gift',
                      subtitle: 'Watch a short video for 50 coins',
                      cta: 'FREE',
                      candy: Candy.blue,
                      onTap: () async {
                        if (await s.ads.showRewarded('shop_gift')) {
                          s.player.addCoins(50);
                          Audio.instance.fx(Sfx.coin, HapticKind.medium);
                        } else if (context.mounted) {
                          toast(context, 'No video available right now');
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    if (!d.removeAds)
                      _OfferRow(
                        art: ArtKind.chest,
                        title: 'Remove Ads',
                        subtitle: 'No more interstitials. Forever.',
                        cta: iap.priceOf(Catalog.byId('remove_ads')),
                        candy: Candy.ink,
                        onTap: () => _buy(Catalog.byId('remove_ads')),
                      ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: iap.restore,
                        child: Text(
                          'Restore purchases',
                          style: AppText.body(15, color: AppColors.primary, weight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Text(
                      'Prices include applicable taxes. VIP renews monthly until cancelled in Google Play. '
                      'Purchases are verified securely before items are granted.',
                      textAlign: TextAlign.center,
                      style: AppText.body(11, color: AppColors.inkFaint, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (busy)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.ink.withValues(alpha: 0.28),
              child: Center(
                child: CandyPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                      const SizedBox(height: 12),
                      Text(
                        iap.state == PurchaseState.verifying ? 'Verifying purchase…' : 'Talking to Google Play…',
                        style: AppText.body(16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VipCard extends StatelessWidget {
  const _VipCard({required this.active, required this.price, this.onTap});
  final bool active;
  final String price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const perks = ['No ads', 'Unlimited lives', '2× coins', '3 free hints daily'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const GameArt(ArtKind.crown, size: 36),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PUZZLE PASS', style: AppText.label(11, color: Colors.white.withValues(alpha: 0.75))),
                    const SizedBox(height: 2),
                    Text('VIP', style: AppText.display(26, color: Colors.white)),
                    Text(
                      active ? 'You\'re a VIP — thank you!' : 'The ultimate puzzle experience',
                      style: AppText.body(14, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final p in perks)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      p,
                      style: AppText.body(14, color: Colors.white, weight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          CandyButton(
            label: active ? 'Active' : 'Join for $price',
            candy: Candy.white,
            height: 54,
            depth: 0,
            pulse: !active,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _GemPack extends StatelessWidget {
  const _GemPack({required this.item, required this.tier, required this.price, required this.onTap});
  final StoreItem item;
  final int tier;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = item.badge;
    return CandyPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Candy.blue.light, borderRadius: BorderRadius.circular(14)),
              child: Stack(
                children: [
                  Center(child: GameArt(ArtKind.gem, size: 36 + tier * 6.0)),
                  if (badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Pill(badge, color: tier >= 3 ? AppColors.goldDeep : AppColors.primary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(item.subtitle, textAlign: TextAlign.center, style: AppText.display(17)),
          const SizedBox(height: 8),
          CandyButton(label: price, candy: Candy.ink, height: 42, fontSize: 15, onTap: onTap),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.art,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.candy,
    required this.onTap,
    this.ctaArt,
  });
  final ArtKind art;
  final String title;
  final String subtitle;
  final String cta;
  final ArtKind? ctaArt;
  final Candy candy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CandyPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: candy.light, borderRadius: BorderRadius.circular(14)),
              child: GameArt(art, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(17)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.body(13, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CandyButton(
              label: cta,
              candy: Candy.ink,
              height: 40,
              width: 96,
              fontSize: 15,
              trailing: ctaArt == null ? null : GameArt(ctaArt!, size: 18),
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
