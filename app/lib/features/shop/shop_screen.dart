import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/outlined_text.dart';
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
                    const Center(child: RibbonBanner('Candy Shop', candy: Candy.pink, fontSize: 30, width: 300)),
                    const SizedBox(height: 14),
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
                      childAspectRatio: 0.86,
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
                        candy: Candy.purple,
                        onTap: () => _buy(Catalog.byId('remove_ads')),
                      ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: iap.restore,
                        child: Text('Restore purchases', style: AppText.body(15, color: Colors.white70)),
                      ),
                    ),
                    Text(
                      'Prices include applicable taxes. VIP renews monthly until cancelled in Google Play. '
                      'Purchases are verified securely before items are granted.',
                      textAlign: TextAlign.center,
                      style: AppText.body(11, color: Colors.white54, weight: FontWeight.w500),
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
              color: Colors.black45,
              child: Center(
                child: CandyPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.royal),
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

class _VipCard extends StatefulWidget {
  const _VipCard({required this.active, required this.price, this.onTap});
  final bool active;
  final String price;
  final VoidCallback? onTap;

  @override
  State<_VipCard> createState() => _VipCardState();
}

class _VipCardState extends State<_VipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const perks = ['No ads', 'Unlimited lives', '2× coins', '3 free hints daily'];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A0B5E), Color(0xFF6A1B9A), Color(0xFFB8327F)],
        ),
        border: Border.all(color: const Color(0xFFFFD54A), width: 3),
        boxShadow: [BoxShadow(color: const Color(0xFFFFB800).withValues(alpha: 0.45), blurRadius: 24)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            // Moving shine sweep.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shine,
                builder: (_, _) => FractionalTranslation(
                  translation: Offset(_shine.value * 3 - 1.5, 0),
                  child: Transform.rotate(
                    angle: 0.4,
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const GameArt(ArtKind.crown, size: 52),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const OutlinedText(
                              'Puzzle Pass VIP',
                              size: 26,
                              textAlign: TextAlign.left,
                              gradient: LinearGradient(colors: [Color(0xFFFFF59A), Color(0xFFFFB800)]),
                            ),
                            Text(
                              widget.active ? 'You\'re a VIP — thank you!' : 'The ultimate puzzle experience',
                              style: AppText.body(14, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in perks)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF7CFFB2), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                p,
                                style: AppText.body(13, color: Colors.white, weight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CandyButton(
                    label: widget.active ? 'Active' : 'Join for ${widget.price}',
                    candy: Candy.gold,
                    height: 58,
                    pulse: !widget.active,
                    onTap: widget.onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CandyPanel(
          rim: tier >= 3 ? Candy.gold : Candy.purple,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i <= tier; i++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(i * 2.1) * 16 * (tier > 0 ? 1 : 0),
                          math.sin(i * 2.1) * 10 * (tier > 0 ? 1 : 0),
                        ),
                        child: GameArt(ArtKind.gem, size: 40 + tier * 4.0),
                      ),
                  ],
                ),
              ),
              Text(item.subtitle, style: AppText.display(20, color: AppColors.ink)),
              const SizedBox(height: 6),
              CandyButton(label: price, candy: Candy.green, height: 46, onTap: onTap),
            ],
          ),
        ),
        if (item.badge != null)
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.heart,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(item.badge!, style: AppText.display(12)),
              ),
            ),
          ),
      ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: CandyPanel(
        rim: candy,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            GameArt(art, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(19, color: AppColors.ink)),
                  Text(subtitle, style: AppText.body(12, color: AppColors.inkSoft)),
                ],
              ),
            ),
            CandyButton(
              label: cta,
              candy: Candy.green,
              height: 48,
              width: 110,
              trailing: ctaArt == null ? null : GameArt(ctaArt!, size: 22),
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
