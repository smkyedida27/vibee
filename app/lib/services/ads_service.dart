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
}
