import '../state/player.dart';
import 'ads_factory_stub.dart' if (dart.library.io) 'ads_factory_mobile.dart' as impl;

/// Ad placements. Rewarded ads are always opt-in; interstitials only between levels.
abstract class AdsService {
  static AdsService create() => impl.createAdsService();

  Future<void> init();

  /// Whether a rewarded ad can be shown right now.
  bool get rewardedReady;

  /// Shows a rewarded ad; resolves true only if the reward was earned.
  Future<bool> showRewarded(String placement);

  Future<void> showInterstitial();

  /// True when the consent framework requires a "Privacy options" entry point (GDPR).
  bool get privacyOptionsRequired => false;

  /// Re-opens the consent form so the player can change their choice.
  Future<void> showPrivacyOptions() async {}
}

/// Enforces the rewarded-ad caps from docs/MONETIZATION.md on top of any [AdsService]:
/// at most [perPlacement] rewards per placement and [perDay] in total per UTC day.
class CappedAdsService implements AdsService {
  CappedAdsService(this._inner, this._player);
  static const perPlacement = 3;
  static const perDay = 10;

  final AdsService _inner;
  final PlayerStore _player;

  /// Whether [placement] can still grant a reward today.
  bool canReward(String placement) =>
      _player.rewardedCount(placement) < perPlacement && _player.rewardedCount(null) < perDay;

  @override
  Future<void> init() => _inner.init();

  @override
  bool get rewardedReady => _inner.rewardedReady;

  @override
  Future<bool> showRewarded(String placement) async {
    if (!canReward(placement)) return false;
    final ok = await _inner.showRewarded(placement);
    if (ok) _player.recordRewarded(placement);
    return ok;
  }

  @override
  Future<void> showInterstitial() => _inner.showInterstitial();

  @override
  bool get privacyOptionsRequired => _inner.privacyOptionsRequired;

  @override
  Future<void> showPrivacyOptions() => _inner.showPrivacyOptions();
}

/// Used on web/desktop and in tests: simulates a successful rewarded view in debug
/// builds so the flows remain testable, and never shows anything in release.
class NoopAdsService implements AdsService {
  NoopAdsService({this.simulateRewards = false});
  final bool simulateRewards;

  @override
  Future<void> init() async {}

  @override
  bool get rewardedReady => simulateRewards;

  @override
  Future<bool> showRewarded(String placement) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return simulateRewards;
  }

  @override
  Future<void> showInterstitial() async {}

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
