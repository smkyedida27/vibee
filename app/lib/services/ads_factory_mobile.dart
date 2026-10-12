import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_service.dart';

AdsService createAdsService() =>
    (Platform.isAndroid || Platform.isIOS) ? AdMobService() : NoopAdsService(simulateRewards: kDebugMode);

/// AdMob implementation with UMP consent, preloading and automatic reload.
/// Unit ids come from --dart-define; Google's public test units are the default.
class AdMobService implements AdsService {
  static final _rewardedId = Platform.isAndroid
      ? const String.fromEnvironment('ADMOB_REWARDED_ANDROID', defaultValue: 'ca-app-pub-3940256099942544/5224354917')
      : const String.fromEnvironment('ADMOB_REWARDED_IOS', defaultValue: 'ca-app-pub-3940256099942544/1712485313');
  static final _interstitialId = Platform.isAndroid
      ? const String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID', defaultValue: 'ca-app-pub-3940256099942544/1033173712')
      : const String.fromEnvironment('ADMOB_INTERSTITIAL_IOS', defaultValue: 'ca-app-pub-3940256099942544/4411468910');

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _initialised = false;
  int _rewardedRetry = 0;

  @override
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    await _gatherConsent();
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _loadRewarded();
    _loadInterstitial();
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      },
      (error) {
        debugPrint('consent error: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedRetry = 0;
          _rewarded = ad;
        },
        onAdFailedToLoad: (e) {
          _rewarded = null;
          // Exponential backoff, capped at ~1 minute.
          final wait = Duration(seconds: 1 << (_rewardedRetry++).clamp(0, 6));
          Timer(wait, _loadRewarded);
        },
      ),
    );
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) {
          _interstitial = null;
          Timer(const Duration(seconds: 45), _loadInterstitial);
        },
      ),
    );
  }

  @override
  bool get rewardedReady => _rewarded != null;

  @override
  Future<bool> showRewarded(String placement) async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
        if (!result.isCompleted) result.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
        done.complete();
      },
    );
    await ad.show();
    return done.future;
  }
}
