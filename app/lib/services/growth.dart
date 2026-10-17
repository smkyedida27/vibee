import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/common/game_type.dart';
import '../state/player.dart';
import 'analytics.dart';
import 'api_client.dart';

/// Play Store listing; the `referrer` parameter survives install via the Play Install Referrer.
const storeUrl = 'https://play.google.com/store/apps/details?id=com.quintile.app';

String inviteLink(String? code) =>
    code == null ? storeUrl : '$storeUrl&referrer=${Uri.encodeQueryComponent('invite=$code')}';

String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Spoiler-free result text, Wordle style: what you did, never the answer.
String buildResultShare({
  required GameType game,
  required bool daily,
  required int stars,
  required Duration elapsed,
  required int hints,
  String? grid,
  int? level,
  int streak = 0,
  int? rank,
  String? inviteCode,
  String? date,
}) {
  final b = StringBuffer();
  b.writeln(
    daily
        ? '🧩 Quintile Daily · ${game.title}${date == null ? '' : ' · $date'}'
        : level != null
        ? '🧩 Quintile · Level $level · ${game.title}'
        : '🧩 Quintile · ${game.title}',
  );
  if (grid != null && grid.isNotEmpty) b.writeln(grid);
  final starLine = '${'⭐' * stars}${'☆' * (3 - stars).clamp(0, 3)}';
  b.writeln('$starLine  ⏱ ${_clock(elapsed)}${hints == 0 ? '  💡 no hints' : '  💡 $hints'}');
  final extras = [if (streak > 1) '🔥 $streak-day streak', if (rank != null) '🏆 Rank #$rank today'];
  if (extras.isNotEmpty) b.writeln(extras.join('  ·  '));
  b.writeln();
  b.writeln(daily ? 'Can you beat me on today\'s puzzle?' : 'Think you can do better?');
  if (inviteCode != null) b.writeln('Use my code $inviteCode for 20 free 💎');
  b.write(inviteLink(inviteCode));
  return b.toString();
}

String buildInviteShare(String? code) {
  final b = StringBuffer()
    ..writeln('🧩 I\'m playing Quintile: Word Connect, Crowns, Sudoku, Word Ladder and Number Merge.')
    ..writeln('A new daily challenge every day. Come race me on the leaderboard!');
  if (code != null) b.writeln('Enter my invite code $code and we both get 20 💎');
  b.write(inviteLink(code));
  return b.toString();
}

/// Sharing, invites and review prompts: the loops that bring new players in.
class GrowthService {
  GrowthService(this._prefs, this._api, this._player, this._analytics, {InAppReview? review})
    : _review = review ?? InAppReview.instance;

  final SharedPreferences _prefs;
  final ApiClient _api;
  final PlayerStore _player;
  final Analytics _analytics;
  final InAppReview _review;

  static const _codeKey = 'growth.inviteCode';
  static const _reviewKey = 'growth.reviewAskedAt';
  static const _winsKey = 'growth.wins';

  /// The player's invite (friend) code, cached so sharing works offline after the first fetch.
  String? get inviteCode => _prefs.getString(_codeKey);

  /// Fetches invite stats and refreshes the cached code. Throws [ApiException] when offline.
  Future<Map<String, dynamic>> referralStats() async {
    final s = await _api.referral();
    final code = s['inviteCode'] as String?;
    if (code != null) await _prefs.setString(_codeKey, code);
    return s;
  }

  /// Warms the invite code cache in the background.
  Future<void> warmUp() async {
    if (inviteCode != null) return;
    try {
      await referralStats();
    } catch (e) {
      debugPrint('invite code fetch skipped: $e');
    }
  }

  Rect? _origin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
    return null;
  }

  Future<void> shareText(BuildContext context, String text, {required String kind}) async {
    _analytics.log('share', {'kind': kind});
    try {
      await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: _origin(context)));
    } catch (e) {
      debugPrint('share failed: $e');
    }
  }

  Future<void> shareInvite(BuildContext context) async {
    if (inviteCode == null) await warmUp();
    if (!context.mounted) return;
    await shareText(context, buildInviteShare(inviteCode), kind: 'invite');
  }

  /// Redeems a friend's invite code. Returns gems granted; throws [ApiException] on failure.
  Future<int> redeem(String code) async {
    final r = await _api.redeemReferral(code.trim().toUpperCase());
    final wallet = r['wallet'] as Map<String, dynamic>?;
    final gems = (wallet?['gems'] as num?)?.toInt();
    if (gems != null) _player.setPaidGems(gems);
    _analytics.log('invite_redeemed', const {});
    return (r['gemsGranted'] as num?)?.toInt() ?? 0;
  }

  /// Asks for a Play review at a happy moment: after a strong win, once the player has won
  /// a handful of puzzles over at least two days, and never more than once per 120 days.
  Future<void> onWin({required int stars}) async {
    final wins = (_prefs.getInt(_winsKey) ?? 0) + 1;
    await _prefs.setInt(_winsKey, wins);
    if (stars < 3 || wins < 6) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final first = _player.data.firstSeenAt ?? now;
    if (now - first < const Duration(days: 2).inMilliseconds) return;
    final asked = _prefs.getInt(_reviewKey);
    if (asked != null && now - asked < const Duration(days: 120).inMilliseconds) return;
    try {
      if (!await _review.isAvailable()) return;
      await _prefs.setInt(_reviewKey, now);
      _analytics.log('review_prompt', const {});
      await _review.requestReview();
    } catch (e) {
      debugPrint('review prompt skipped: $e');
    }
  }
}
