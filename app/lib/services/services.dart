import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/audio/sfx.dart';
import '../state/player.dart';
import 'ads_service.dart';
import 'analytics.dart';
import 'api_client.dart';
import 'content_repo.dart';
import 'firebase_setup.dart';
import 'growth.dart';
import 'purchase_service.dart';
import 'reminders.dart';

/// Composition root: every long-lived service, created once in main().
class AppServices {
  AppServices._(
    this.prefs,
    this.player,
    this.api,
    this.content,
    this.ads,
    this.purchases,
    this.analytics,
    this.sync,
    this.growth,
    this.reminders,
  );

  final SharedPreferences prefs;
  final PlayerStore player;
  final ApiClient api;
  final ContentRepo content;
  final AdsService ads;
  final PurchaseService purchases;
  final Analytics analytics;
  final SyncService sync;
  final GrowthService growth;
  final ReminderService reminders;

  static Future<AppServices> create({
    SharedPreferences? prefs,
    AdsService? ads,
    ApiClient? api,
    ReminderService? reminders,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final player = PlayerStore(p);
    final client = api ?? ApiClient(p);
    final analytics = Analytics([
      if (kDebugMode) DebugAnalyticsSink(),
      if (FirebaseSetup.ready) FirebaseAnalyticsSink(),
    ]);
    final content = ContentRepo(p, client);
    await content.init();
    final s = AppServices._(
      p,
      player,
      client,
      content,
      CappedAdsService(ads ?? AdsService.create(), player),
      PurchaseService(client, player, analytics),
      analytics,
      SyncService(client, player),
      GrowthService(p, client, player, analytics),
      reminders ?? ReminderService(),
    );
    _applySettings(player);
    player.addListener(() {
      _applySettings(player);
      // Cheap no-op unless the reminder setting, hour, streak or today's completion changed.
      unawaited(s.reminders.sync(player.data));
    });
    // A fresh guest account (first launch, or an unrecoverable session) gets the local
    // progress, profile and any Play purchases re-attached.
    client.onNewAccount = () {
      unawaited(s.sync.push());
      unawaited(s.purchases.resyncOwned().catchError((Object e) => debugPrint('iap resync: $e')));
      if (player.data.onboarded) unawaited(s.pushProfile());
    };
    return s;
  }

  static void _applySettings(PlayerStore p) {
    Audio.instance
      ..soundOn = p.data.settings.sound
      ..hapticsOn = p.data.settings.haptics;
  }

  /// Sends name, avatar, country and locale to the server (leaderboards, Country scope).
  /// Fire-and-forget: the local profile is the source of truth for display.
  Future<void> pushProfile() async {
    await reminders.init(); // resolves the device time zone
    final d = player.data;
    final loc = PlatformDispatcher.instance.locale;
    final cc = loc.countryCode;
    final country = d.country ?? ((cc != null && RegExp(r'^[A-Z]{2}$').hasMatch(cc)) ? cc : null);
    if (country != null && d.country == null) player.updateProfile(country: country);
    final lang = loc.languageCode.toLowerCase();
    try {
      await api.updatePreferences({
        'displayName': ?cleanDisplayName(d.displayName),
        'avatarId': d.avatar.clamp(0, 63),
        'timezone': ?reminders.zoneId,
        'country': ?country,
        if (RegExp(r'^[a-z]{2,3}$').hasMatch(lang)) 'locale': country == null ? lang : '$lang-$country',
      });
    } catch (e) {
      debugPrint('profile push skipped: $e');
    }
  }

  /// Non-blocking startup work (network, ads, billing). Failures never block play.
  void warmUp() {
    unawaited(Audio.instance.init());
    unawaited(ads.init().catchError((Object e) => debugPrint('ads init: $e')));
    unawaited(purchases.init().catchError((Object e) => debugPrint('iap init: $e')));
    unawaited(
      sync.pull().then((_) {
        FirebaseSetup.setUser(api.userId);
        if (player.data.onboarded) return pushProfile();
      }),
    );
    unawaited(reminders.sync(player.data, force: true));
    unawaited(growth.warmUp());
    if (player.data.settings.reminders) {
      unawaited(FirebaseSetup.refreshPush(api).catchError((Object e) => debugPrint('push: $e')));
    }
  }
}

/// Backs up local progress to `PUT /me/progress` with optimistic concurrency and
/// merges on conflict (max stars per level, best streak, union of daily completions).
class SyncService {
  SyncService(this._api, this._player);
  final ApiClient _api;
  final PlayerStore _player;
  int _serverVersion = 0;
  bool _busy = false;

  Future<void> pull() async {
    try {
      final res = await _api.getProgress();
      if (res == null) return;
      _serverVersion = (res['version'] as num?)?.toInt() ?? 0;
      final data = res['data'] as Map<String, dynamic>?;
      if (data != null && data.isNotEmpty) _merge(data);
      // Entitlements are server-owned.
      final ent = await _api.entitlements();
      final vip = ent['vipUntil'] as String?;
      _player.setEntitlements(
        removeAds: ent['removeAds'] == true,
        vipUntil: vip == null ? null : DateTime.parse(vip).millisecondsSinceEpoch,
      );
      await refreshWallet();
    } on ApiException catch (e) {
      debugPrint('sync pull skipped: $e');
    } catch (e) {
      debugPrint('sync pull failed: $e');
    }
  }

  /// Refreshes the cached purchased-gem balance from the server wallet.
  Future<void> refreshWallet() async {
    try {
      final w = await _api.wallet();
      _player.setPaidGems((w['gems'] as num?)?.toInt() ?? 0);
    } on ApiException catch (e) {
      debugPrint('wallet refresh skipped: $e');
    }
  }

  Future<void> push({int attempt = 0}) async {
    if (_busy) return;
    _busy = true;
    try {
      final res = await _api.putProgress(_serverVersion, _player.data.toJson());
      _serverVersion = (res['version'] as num?)?.toInt() ?? _serverVersion + 1;
    } on ApiException catch (e) {
      if (e.isConflict && e.body != null) {
        // The 409 body is the server's current snapshot: {version, data, updatedAt}.
        final current = e.body!;
        if (current['version'] != null && attempt < 3) {
          _serverVersion = (current['version'] as num?)?.toInt() ?? _serverVersion;
          final data = current['data'] as Map<String, dynamic>?;
          if (data != null) _merge(data);
          _busy = false;
          return push(attempt: attempt + 1);
        }
      }
      debugPrint('sync push skipped: $e');
    } finally {
      _busy = false;
    }
  }

  void _merge(Map<String, dynamic> remoteJson) {
    final remote = PlayerData.fromJson(remoteJson);
    final local = _player.data;
    final merged = local.toJson();
    final stars = Map<int, int>.of(local.levelStars);
    remote.levelStars.forEach((k, v) {
      if (v > (stars[k] ?? 0)) stars[k] = v;
    });
    merged['levelStars'] = stars.map((k, v) => MapEntry('$k', v));
    merged['bestStreak'] = remote.bestStreak > local.bestStreak ? remote.bestStreak : local.bestStreak;
    if (remote.lastStreakDate != null &&
        (local.lastStreakDate == null || remote.lastStreakDate!.compareTo(local.lastStreakDate!) > 0)) {
      merged['streak'] = remote.streak;
      merged['lastStreakDate'] = remote.lastStreakDate;
    }
    if (remote.dailyDate == local.dailyDate) {
      merged['dailyDone'] = {...local.dailyDone, ...remote.dailyDone}.toList();
    }
    merged['onboarded'] = local.onboarded || remote.onboarded;
    merged['xp'] = remote.xp > local.xp ? remote.xp : local.xp;
    final stages = Map<String, int>.of(local.stageStars);
    remote.stageStars.forEach((k, v) {
      if (v > (stages[k] ?? 0)) stages[k] = v;
    });
    merged['stageStars'] = stages;
    _player.replaceFromSnapshot(merged);
  }
}

/// Exposes [AppServices] to the widget tree and rebuilds dependents on player changes.
class AppScope extends InheritedNotifier<PlayerStore> {
  AppScope({super.key, required this.services, required super.child}) : super(notifier: services.player);

  final AppServices services;

  static AppServices of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope missing');
    return s!.services;
  }

  /// Read without subscribing to rebuilds (for callbacks).
  static AppServices read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).services;
}

extension AppContext on BuildContext {
  AppServices get services => AppScope.read(this);
  PlayerStore get player => AppScope.of(this).player;
}
