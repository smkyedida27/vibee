import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../state/player.dart';
import 'analytics.dart';
import 'api_client.dart';

/// Static catalog mirrored from docs/CONTRACT.md §6. Display prices come from the
/// store at runtime; [fallbackPrice] is only shown when the store is unreachable.
class StoreItem {
  const StoreItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.gems = 0,
    this.consumable = true,
    this.subscription = false,
    this.badge,
    required this.fallbackPrice,
  });

  final String id;
  final String title;
  final String subtitle;
  final int gems;
  final bool consumable;
  final bool subscription;
  final String? badge;
  final String fallbackPrice;
}

class Catalog {
  static const items = <StoreItem>[
    StoreItem(id: 'gems_small', title: 'Handful of Gems', subtitle: '80 gems', gems: 80, fallbackPrice: '\$0.99'),
    StoreItem(
      id: 'gems_medium',
      title: 'Pouch of Gems',
      subtitle: '500 gems',
      gems: 500,
      badge: 'POPULAR',
      fallbackPrice: '\$4.99',
    ),
    StoreItem(id: 'gems_large', title: 'Chest of Gems', subtitle: '1,200 gems', gems: 1200, fallbackPrice: '\$9.99'),
    StoreItem(
      id: 'gems_mega',
      title: 'Vault of Gems',
      subtitle: '3,000 gems',
      gems: 3000,
      badge: 'BEST VALUE',
      fallbackPrice: '\$19.99',
    ),
    StoreItem(
      id: 'remove_ads',
      title: 'Remove Ads',
      subtitle: 'No more interstitial ads, forever',
      consumable: false,
      fallbackPrice: '\$3.99',
    ),
    StoreItem(
      id: 'vip_monthly',
      title: 'Puzzle Pass VIP',
      subtitle: 'No ads • Unlimited lives • 2× coins • 3 free hints daily',
      consumable: false,
      subscription: true,
      badge: 'VIP',
      fallbackPrice: '\$4.99/mo',
    ),
  ];

  static StoreItem byId(String id) => items.firstWhere((i) => i.id == id);
}

enum PurchaseState { idle, pending, verifying, success, failed, unavailable }

/// Google Play Billing via `in_app_purchase`. Every purchase is verified by the
/// backend (`POST /purchases/google/verify`) before anything is granted, and the
/// purchase is only acknowledged/consumed after a successful verification, so a
/// crash or offline moment never loses or duplicates a purchase.
class PurchaseService extends ChangeNotifier {
  PurchaseService(this._api, this._player, this._analytics);

  final ApiClient _api;
  final PlayerStore _player;
  final Analytics _analytics;
  final Map<String, ProductDetails> products = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool available = false;
  PurchaseState state = PurchaseState.idle;
  String? lastError;

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!_supported) return;
    final iap = InAppPurchase.instance;
    available = await iap.isAvailable();
    if (!available) return;
    _sub = iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        lastError = '$e';
        _set(PurchaseState.failed);
      },
    );
    final resp = await iap.queryProductDetails(Catalog.items.map((i) => i.id).toSet());
    for (final p in resp.productDetails) {
      products[p.id] = p;
    }
    notifyListeners();
    await resyncOwned();
  }

  /// Re-delivers purchases Play still holds (owned non-consumables and any purchase whose
  /// verification failed earlier) so they are verified and acknowledged before Play's
  /// 3-day auto-refund, and re-attached after a new account. The server grants each
  /// purchase token at most once. No UI feedback.
  Future<void> resyncOwned() async {
    if (!available) return;
    _silentRestore = true;
    await InAppPurchase.instance.restorePurchases();
    Timer(const Duration(seconds: 20), () => _silentRestore = false);
  }

  bool _silentRestore = false;

  String priceOf(StoreItem item) => products[item.id]?.price ?? item.fallbackPrice;

  Future<void> buy(StoreItem item) async {
    final product = products[item.id];
    if (!available || product == null) {
      _set(PurchaseState.unavailable);
      return;
    }
    _analytics.log('purchase_start', {'product': item.id});
    _set(PurchaseState.pending);
    final param = PurchaseParam(productDetails: product);
    if (item.consumable) {
      // autoConsume false: we consume only after server verification.
      await InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: false);
    } else {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> restore() async {
    if (!available) return;
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      try {
        await _handle(p);
      } catch (e) {
        // Never let one bad purchase stall the batch or leave the UI stuck on "verifying".
        debugPrint('purchase ${p.productID} failed: $e');
        if (!_silentRestore) {
          lastError = 'Something went wrong finishing your purchase. Try Restore purchases.';
          _set(PurchaseState.failed);
        }
      }
    }
  }

  Future<void> _handle(PurchaseDetails p) async {
    switch (p.status) {
      case PurchaseStatus.pending:
        // A slow payment re-delivered by the startup resync must not block the Shop.
        if (!_silentRestore) _set(PurchaseState.pending);
      case PurchaseStatus.error:
        lastError = p.error?.message;
        _analytics.log('purchase_error', {'product': p.productID, 'error': p.error?.code ?? ''});
        _set(PurchaseState.failed);
        if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
      case PurchaseStatus.canceled:
        _set(PurchaseState.idle);
        if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
      case PurchaseStatus.purchased:
        await _verifyAndGrant(p);
      case PurchaseStatus.restored:
        await _verifyAndGrant(p, silent: _silentRestore);
    }
  }

  Future<void> _verifyAndGrant(PurchaseDetails p, {bool silent = false}) async {
    if (!silent) _set(PurchaseState.verifying);
    try {
      final res = await _api.verifyGooglePurchase(p.productID, p.verificationData.serverVerificationData);
      // Server is the source of truth for balances and entitlements.
      final wallet = res['wallet'] as Map<String, dynamic>?;
      if (wallet != null) _player.setPaidGems((wallet['gems'] as num).toInt());
      final ent = res['entitlements'] as Map<String, dynamic>?;
      if (ent != null) {
        final vip = ent['vipUntil'] as String?;
        _player.setEntitlements(
          removeAds: ent['removeAds'] == true,
          vipUntil: vip == null ? null : DateTime.parse(vip).millisecondsSinceEpoch,
        );
      }
      if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
      if (defaultTargetPlatform == TargetPlatform.android &&
          Catalog.items.any((i) => i.id == p.productID && i.consumable)) {
        final android = InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await android.consumePurchase(p);
      }
      if (silent) return;
      _analytics.log('purchase_success', {'product': p.productID});
      _set(PurchaseState.success);
    } on ApiException catch (e) {
      if (e.code == 'PURCHASE_ALREADY_CLAIMED') {
        // Already granted (to this or an earlier account): finish it so Play stops re-delivering
        // it and a consumable can be bought again.
        if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
        if (defaultTargetPlatform == TargetPlatform.android &&
            Catalog.items.any((i) => i.id == p.productID && i.consumable)) {
          await InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(p);
        }
      }
      if (silent) return;
      // Otherwise leave the purchase un-acknowledged; Play re-delivers it on next launch and
      // refunds automatically if it is never acknowledged.
      lastError = e.isOffline ? 'You appear to be offline. We\'ll finish this purchase when you reconnect.' : e.message;
      _set(PurchaseState.failed);
    }
  }

  void _set(PurchaseState s) {
    state = s;
    notifyListeners();
  }

  /// Called by the UI after it has shown a terminal state (success/failed) to the player.
  void acknowledgeState() {
    if (state == PurchaseState.success || state == PurchaseState.failed || state == PurchaseState.unavailable) {
      state = PurchaseState.idle;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
