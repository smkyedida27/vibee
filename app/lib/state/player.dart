import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/common/game_type.dart';

/// Economy tuning. Kept in one place so live-ops can move it to remote config.
class Economy {
  static const maxHearts = 5;
  static const heartRegen = Duration(minutes: 25);
  static const startCoins = 300;
  static const startGems = 15;
  static const startHints = 3;
  static const hintPackCoins = 250; // 3 hints
  static const heartRefillGems = 30;
  static const continueGems = 12;
  static const vipDailyHints = 3;

  static int levelCoins(int stars) => 20 + 15 * stars;

  /// 7-day login calendar.
  static const loginRewards = <LoginReward>[
    LoginReward(coins: 100),
    LoginReward(coins: 150),
    LoginReward(hints: 2),
    LoginReward(coins: 250),
    LoginReward(gems: 10),
    LoginReward(coins: 400, hints: 1),
    LoginReward(gems: 30, coins: 500, hints: 3),
  ];
}

class LoginReward {
  const LoginReward({this.coins = 0, this.gems = 0, this.hints = 0});
  final int coins, gems, hints;
}

class GameStats {
  GameStats({this.played = 0, this.won = 0, this.bestMs, this.totalMs = 0});
  int played, won;
  int? bestMs;
  int totalMs;

  Map<String, dynamic> toJson() => {'p': played, 'w': won, 'b': bestMs, 't': totalMs};
  factory GameStats.fromJson(Map<String, dynamic> j) =>
      GameStats(played: j['p'] ?? 0, won: j['w'] ?? 0, bestMs: j['b'], totalMs: j['t'] ?? 0);
}

class Settings {
  bool sound = true;
  bool haptics = true;
  bool music = true;
  bool reducedMotion = false;
  bool reminders = false;
  int reminderHour = 19;
  bool highContrast = false;

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'haptics': haptics,
    'music': music,
    'reducedMotion': reducedMotion,
    'reminders': reminders,
    'reminderHour': reminderHour,
    'highContrast': highContrast,
  };

  static Settings fromJson(Map<String, dynamic> j) => Settings()
    ..sound = j['sound'] ?? true
    ..haptics = j['haptics'] ?? true
    ..music = j['music'] ?? true
    ..reducedMotion = j['reducedMotion'] ?? false
    ..reminders = j['reminders'] ?? false
    ..reminderHour = j['reminderHour'] ?? 19
    ..highContrast = j['highContrast'] ?? false;
}

/// Everything persisted for a player. Local-first; synced as an opaque snapshot
/// to `PUT /me/progress` when online (see SyncService).
class PlayerData {
  bool onboarded = false;
  String displayName = 'Player';
  int avatar = 0;
  String? country;

  int coins = Economy.startCoins;

  /// Free gems (starter grant, login calendar, spin). Local-first like coins.
  int gems = Economy.startGems;

  /// Purchased gems: a cached mirror of the server wallet (`GET /me/wallet`), which is
  /// the only authority for them. Spent only through `POST /me/wallet/spend`.
  int paidGems = 0;
  int hints = Economy.startHints;
  int hearts = Economy.maxHearts;
  int? heartClockStart; // epoch ms when regen timer started
  int? unlimitedHeartsUntil;

  Map<int, int> levelStars = {};
  Map<String, GameStats> stats = {};

  // Daily challenge + streak (UTC dates, yyyy-MM-dd).
  String? dailyDate;
  Set<String> dailyDone = {};
  int streak = 0;
  int bestStreak = 0;
  String? lastStreakDate;

  // Rewards.
  int loginDay = 0;
  String? lastLoginClaim;
  String? lastFreeSpin;
  String? lastVipHintsDate;

  // Entitlements (mirrored from server; server is source of truth).
  bool removeAds = false;
  int? vipUntil;

  // Ads pacing.
  int levelsSinceInterstitial = 0;
  int? lastInterstitialAt;
  int? firstSeenAt; // epoch ms of first launch; no interstitials in the first 2 days
  String? rewardedDate; // UTC day the counts below belong to
  Map<String, int> rewardedCounts = {};

  Settings settings = Settings();
  int snapshotVersion = 0;

  int get highestCleared => levelStars.keys.fold(0, (m, k) => k > m ? k : m);
  int get currentLevel => highestCleared + 1;
  int get totalStars => levelStars.values.fold(0, (a, b) => a + b);
  bool get isVip => vipUntil != null && vipUntil! > DateTime.now().millisecondsSinceEpoch;
  bool get adsDisabled => removeAds || isVip;
  int get totalGems => gems + paidGems;

  Map<String, dynamic> toJson() => {
    'onboarded': onboarded,
    'displayName': displayName,
    'avatar': avatar,
    'country': country,
    'coins': coins,
    'gems': gems,
    'paidGems': paidGems,
    'hints': hints,
    'hearts': hearts,
    'heartClockStart': heartClockStart,
    'unlimitedHeartsUntil': unlimitedHeartsUntil,
    'levelStars': levelStars.map((k, v) => MapEntry('$k', v)),
    'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
    'dailyDate': dailyDate,
    'dailyDone': dailyDone.toList(),
    'streak': streak,
    'bestStreak': bestStreak,
    'lastStreakDate': lastStreakDate,
    'loginDay': loginDay,
    'lastLoginClaim': lastLoginClaim,
    'lastFreeSpin': lastFreeSpin,
    'lastVipHintsDate': lastVipHintsDate,
    'removeAds': removeAds,
    'vipUntil': vipUntil,
    'levelsSinceInterstitial': levelsSinceInterstitial,
    'lastInterstitialAt': lastInterstitialAt,
    'firstSeenAt': firstSeenAt,
    'rewardedDate': rewardedDate,
    'rewardedCounts': rewardedCounts,
    'settings': settings.toJson(),
    'snapshotVersion': snapshotVersion,
  };

  static PlayerData fromJson(Map<String, dynamic> j) {
    final d = PlayerData()
      ..onboarded = j['onboarded'] ?? false
      ..displayName = j['displayName'] ?? 'Player'
      ..avatar = j['avatar'] ?? 0
      ..country = j['country']
      ..coins = j['coins'] ?? Economy.startCoins
      ..gems = j['gems'] ?? Economy.startGems
      ..paidGems = j['paidGems'] ?? 0
      ..hints = j['hints'] ?? Economy.startHints
      ..hearts = j['hearts'] ?? Economy.maxHearts
      ..heartClockStart = j['heartClockStart']
      ..unlimitedHeartsUntil = j['unlimitedHeartsUntil']
      ..levelStars = ((j['levelStars'] ?? {}) as Map).map((k, v) => MapEntry(int.parse('$k'), v as int))
      ..stats = ((j['stats'] ?? {}) as Map).map(
        (k, v) => MapEntry('$k', GameStats.fromJson((v as Map).cast<String, dynamic>())),
      )
      ..dailyDate = j['dailyDate']
      ..dailyDone = ((j['dailyDone'] ?? []) as List).cast<String>().toSet()
      ..streak = j['streak'] ?? 0
      ..bestStreak = j['bestStreak'] ?? 0
      ..lastStreakDate = j['lastStreakDate']
      ..loginDay = j['loginDay'] ?? 0
      ..lastLoginClaim = j['lastLoginClaim']
      ..lastFreeSpin = j['lastFreeSpin']
      ..lastVipHintsDate = j['lastVipHintsDate']
      ..removeAds = j['removeAds'] ?? false
      ..vipUntil = j['vipUntil']
      ..levelsSinceInterstitial = j['levelsSinceInterstitial'] ?? 0
      ..lastInterstitialAt = j['lastInterstitialAt']
      ..firstSeenAt = j['firstSeenAt']
      ..rewardedDate = j['rewardedDate']
      ..rewardedCounts = ((j['rewardedCounts'] ?? {}) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()))
      ..settings = Settings.fromJson(((j['settings'] ?? {}) as Map).cast<String, dynamic>())
      ..snapshotVersion = j['snapshotVersion'] ?? 0;
    return d;
  }
}

final _nameDisallowed = RegExp(r'[^\p{L}\p{N} _.-]', unicode: true);

/// Normalises a display name to what the server accepts (2–20 letters, digits, space, `_.-`).
/// Returns null when nothing usable is left.
String? cleanDisplayName(String raw) {
  var n = raw.replaceAll(_nameDisallowed, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (n.length > 20) n = n.substring(0, 20).trim();
  return n.length >= 2 ? n : null;
}

String utcDate([DateTime? t]) {
  final d = (t ?? DateTime.now()).toUtc();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _prevUtcDate(String date) => utcDate(DateTime.parse('${date}T00:00:00Z').subtract(const Duration(days: 1)));

/// Result of finishing a level, used by the results screen.
class LevelReward {
  LevelReward({required this.coins, required this.stars, required this.newBest, required this.firstClear});
  final int coins;
  final int stars;
  final bool newBest;
  final bool firstClear;
}

/// Single source of truth for local player state. All mutations persist (debounced).
class PlayerStore extends ChangeNotifier {
  PlayerStore(this._prefs, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        data = PlayerData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Corrupt player data, keeping backup and starting fresh: $e');
        _prefs.setString('$_key.corrupt', raw);
      }
    }
    data.firstSeenAt ??= _now;
    _tickHearts();
    _rollDaily();
    _heartTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (data.hearts < Economy.maxHearts) {
        final before = data.hearts;
        _tickHearts();
        if (data.hearts != before) _changed();
      }
    });
  }

  static const _key = 'player.v1';
  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  PlayerData data = PlayerData();
  Timer? _saveTimer;
  Timer? _heartTimer;

  int get _now => _clock().millisecondsSinceEpoch;

  @override
  void dispose() {
    _heartTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _changed() {
    data.snapshotVersion++;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  Future<void> save() async => _prefs.setString(_key, jsonEncode(data.toJson()));

  void replaceFromSnapshot(Map<String, dynamic> json) {
    data = PlayerData.fromJson(json);
    _tickHearts();
    _rollDaily();
    _changed();
  }

  // ---------------------------------------------------------------- hearts
  bool get unlimitedHearts => data.isVip || (data.unlimitedHeartsUntil != null && data.unlimitedHeartsUntil! > _now);

  void _tickHearts() {
    if (data.hearts >= Economy.maxHearts) {
      data.heartClockStart = null;
      return;
    }
    data.heartClockStart ??= _now;
    // Clock moved backwards (manual change, timezone bug): restart the timer instead of stalling.
    if (data.heartClockStart! > _now) data.heartClockStart = _now;
    final elapsed = _now - data.heartClockStart!;
    final gained = elapsed ~/ Economy.heartRegen.inMilliseconds;
    if (gained > 0) {
      data.hearts = (data.hearts + gained).clamp(0, Economy.maxHearts);
      data.heartClockStart = data.hearts >= Economy.maxHearts
          ? null
          : data.heartClockStart! + gained * Economy.heartRegen.inMilliseconds;
    }
  }

  Duration? get nextHeartIn {
    if (data.hearts >= Economy.maxHearts || data.heartClockStart == null) return null;
    final left = Economy.heartRegen.inMilliseconds - (_now - data.heartClockStart!);
    return Duration(milliseconds: left.clamp(0, Economy.heartRegen.inMilliseconds));
  }

  bool get canPlayLevel => unlimitedHearts || data.hearts > 0;

  void loseHeart() {
    if (unlimitedHearts) return;
    _tickHearts();
    data.hearts = (data.hearts - 1).clamp(0, Economy.maxHearts);
    data.heartClockStart ??= _now;
    _changed();
  }

  void addHeart() {
    _tickHearts();
    data.hearts = (data.hearts + 1).clamp(0, Economy.maxHearts);
    if (data.hearts >= Economy.maxHearts) data.heartClockStart = null;
    _changed();
  }

  void refillHearts() {
    data.hearts = Economy.maxHearts;
    data.heartClockStart = null;
    _changed();
  }

  void grantUnlimitedHearts(Duration d) {
    final base = (data.unlimitedHeartsUntil ?? 0) > _now ? data.unlimitedHeartsUntil! : _now;
    data.unlimitedHeartsUntil = base + d.inMilliseconds;
    _changed();
  }

  // ---------------------------------------------------------------- currency
  void addCoins(int n) {
    data.coins += n;
    _changed();
  }

  bool spendCoins(int n) {
    if (data.coins < n) return false;
    data.coins -= n;
    _changed();
    return true;
  }

  /// Mirrors the server wallet balance (purchased gems).
  void setPaidGems(int n) {
    if (data.paidGems == n) return;
    data.paidGems = n;
    _changed();
  }

  void addGems(int n) {
    data.gems += n;
    _changed();
  }

  bool spendGems(int n) {
    if (data.gems < n) return false;
    data.gems -= n;
    _changed();
    return true;
  }

  void addHints(int n) {
    data.hints += n;
    _changed();
  }

  bool useHint() {
    _grantVipHints();
    if (data.hints <= 0) return false;
    data.hints--;
    _changed();
    return true;
  }

  void _grantVipHints() {
    final today = utcDate(_clock());
    if (data.isVip && data.lastVipHintsDate != today) {
      data.lastVipHintsDate = today;
      data.hints += Economy.vipDailyHints;
    }
  }

  bool buyHintPack() {
    if (!spendCoins(Economy.hintPackCoins)) return false;
    addHints(3);
    return true;
  }

  // ---------------------------------------------------------------- levels
  LevelReward completeLevel({required int level, required int stars, required GameType game, required int durationMs}) {
    final prev = data.levelStars[level] ?? 0;
    final firstClear = prev == 0;
    final best = stars > prev;
    if (best) data.levelStars[level] = stars;
    var coins = firstClear ? Economy.levelCoins(stars) : (best ? 10 * (stars - prev) : 5);
    if (data.isVip) coins *= 2;
    data.coins += coins;
    _recordStat(game, won: true, durationMs: durationMs);
    data.levelsSinceInterstitial++;
    _changed();
    return LevelReward(coins: coins, stars: stars, newBest: best, firstClear: firstClear);
  }

  void failLevel({required GameType game, required int durationMs}) {
    _recordStat(game, won: false, durationMs: durationMs);
    loseHeart();
  }

  void _recordStat(GameType game, {required bool won, required int durationMs}) {
    final s = data.stats.putIfAbsent(game.wire, GameStats.new);
    s.played++;
    if (won) {
      s.won++;
      s.totalMs += durationMs;
      if (s.bestMs == null || durationMs < s.bestMs!) s.bestMs = durationMs;
    }
  }

  // ---------------------------------------------------------------- daily + streak
  void _rollDaily() {
    final today = utcDate(_clock());
    if (data.dailyDate != today) {
      data.dailyDate = today;
      data.dailyDone = {};
    }
    // Streak breaks if yesterday had no qualifying completion.
    if (data.lastStreakDate != null && data.lastStreakDate != today && data.lastStreakDate != _prevUtcDate(today)) {
      data.streak = 0;
    }
  }

  bool dailyCompleted(GameType g) {
    _rollDaily();
    return data.dailyDone.contains(g.wire);
  }

  /// Returns coins awarded.
  int completeDaily(GameType g, {required int durationMs}) {
    _rollDaily();
    final today = data.dailyDate!;
    if (!data.dailyDone.add(g.wire)) return 0;
    _recordStat(g, won: true, durationMs: durationMs);
    if (data.lastStreakDate != today) {
      data.streak = data.lastStreakDate == _prevUtcDate(today) ? data.streak + 1 : 1;
      data.lastStreakDate = today;
      if (data.streak > data.bestStreak) data.bestStreak = data.streak;
    }
    var coins = 60;
    if (data.dailyDone.length == GameType.values.length) coins += 300; // full-set bonus
    if (data.isVip) coins *= 2;
    data.coins += coins;
    _changed();
    return coins;
  }

  // ---------------------------------------------------------------- rewards
  bool get canClaimLogin => data.lastLoginClaim != utcDate(_clock());

  LoginReward? claimLogin() {
    if (!canClaimLogin) return null;
    final today = utcDate(_clock());
    // Missing a day restarts the calendar.
    if (data.lastLoginClaim != null && data.lastLoginClaim != _prevUtcDate(today)) data.loginDay = 0;
    final r = Economy.loginRewards[data.loginDay % Economy.loginRewards.length];
    data.coins += r.coins;
    data.gems += r.gems;
    data.hints += r.hints;
    data.loginDay = (data.loginDay + 1) % Economy.loginRewards.length;
    data.lastLoginClaim = today;
    _changed();
    return r;
  }

  bool get canFreeSpin => data.lastFreeSpin != utcDate(_clock());

  void markFreeSpin() {
    data.lastFreeSpin = utcDate(_clock());
    _changed();
  }

  // ---------------------------------------------------------------- ads pacing
  /// Interstitials: never mid-puzzle, at most every 3 cleared levels and 3 minutes.
  bool shouldShowInterstitial() {
    if (data.adsDisabled) return false;
    if (data.currentLevel <= 8) return false; // protect the first session
    if (_now - (data.firstSeenAt ?? _now) < const Duration(days: 2).inMilliseconds) return false;
    if (data.levelsSinceInterstitial < 3) return false;
    final last = data.lastInterstitialAt;
    return last == null || _now - last > const Duration(minutes: 3).inMilliseconds;
  }

  /// Rewarded views today for [placement], or in total when null.
  int rewardedCount(String? placement) {
    if (data.rewardedDate != utcDate(_clock())) return 0;
    return placement == null
        ? data.rewardedCounts.values.fold(0, (a, b) => a + b)
        : data.rewardedCounts[placement] ?? 0;
  }

  void recordRewarded(String placement) {
    final today = utcDate(_clock());
    if (data.rewardedDate != today) {
      data.rewardedDate = today;
      data.rewardedCounts = {};
    }
    data.rewardedCounts[placement] = (data.rewardedCounts[placement] ?? 0) + 1;
    _changed();
  }

  void markInterstitialShown() {
    data.levelsSinceInterstitial = 0;
    data.lastInterstitialAt = _now;
    _changed();
  }

  // ---------------------------------------------------------------- profile/settings
  void completeOnboarding({required String name, required int avatar}) {
    data
      ..onboarded = true
      ..displayName = cleanDisplayName(name) ?? 'Player'
      ..avatar = avatar;
    _changed();
  }

  void updateProfile({String? name, int? avatar, String? country}) {
    final clean = name == null ? null : cleanDisplayName(name);
    if (clean != null) data.displayName = clean;
    if (avatar != null) data.avatar = avatar;
    if (country != null) data.country = country;
    _changed();
  }

  void updateSettings(void Function(Settings s) f) {
    f(data.settings);
    _changed();
  }

  void setEntitlements({required bool removeAds, int? vipUntil}) {
    data.removeAds = removeAds;
    data.vipUntil = vipUntil;
    _changed();
  }

  Future<void> wipe() async {
    await _prefs.remove(_key);
    data = PlayerData();
    notifyListeners();
  }
}
