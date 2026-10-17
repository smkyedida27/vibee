import 'package:puzzle_hub/services/content_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/common/game_type.dart';
import 'package:puzzle_hub/services/growth.dart';
import 'package:puzzle_hub/services/reminders.dart';
import 'package:puzzle_hub/state/player.dart';

PlayerData _player({bool reminders = true, int hour = 19}) => PlayerData()
  ..settings.reminders = reminders
  ..settings.reminderHour = hour;

void main() {
  group('reminder planning', () {
    test('nothing when reminders are off', () {
      expect(planReminders(_player(reminders: false), DateTime(2026, 10, 17, 9)), isEmpty);
    });

    test('schedules today when the hour is still ahead, then daily', () {
      final slots = planReminders(_player(), DateTime(2026, 10, 17, 9));
      expect(slots, hasLength(7));
      expect(slots.first.at, DateTime(2026, 10, 17, 19));
      expect(slots[1].at, DateTime(2026, 10, 18, 19));
    });

    test('skips today once the hour has passed', () {
      expect(planReminders(_player(), DateTime(2026, 10, 17, 20)).first.at, DateTime(2026, 10, 18, 19));
    });

    test("skips the slot for a puzzle day that's already played", () {
      final now = DateTime(2026, 10, 17, 9);
      final at = DateTime(2026, 10, 17, 19);
      final d = _player()
        ..dailyDate = utcDate(at)
        ..dailyDone = {'CONNECT'};
      expect(planReminders(d, now).first.at, isNot(at));
    });

    test('first reminder protects a streak', () {
      final d = _player()..streak = 5;
      expect(planReminders(d, DateTime(2026, 10, 17, 9)).first.title, contains('5-day streak'));
    });

    test('handles month rollover', () {
      final slots = planReminders(_player(), DateTime(2026, 10, 30, 21));
      expect(slots.first.at, DateTime(2026, 10, 31, 19));
      expect(slots[1].at, DateTime(2026, 11, 1, 19));
    });
  });

  group('share text', () {
    test('daily result is spoiler free and carries the invite', () {
      final t = buildResultShare(
        game: GameType.connect,
        daily: true,
        stars: 2,
        elapsed: const Duration(minutes: 2, seconds: 5),
        hints: 0,
        grid: '🟨🟨🟨🟨',
        streak: 4,
        rank: 12,
        inviteCode: 'ABCD2345',
        date: '2026-10-17',
      );
      expect(t, contains('Daily · Word Connect · 2026-10-17'));
      expect(t, contains('⭐⭐☆'));
      expect(t, contains('2:05'));
      expect(t, contains('4-day streak'));
      expect(t, contains('Rank #12'));
      expect(t, contains('ABCD2345'));
      expect(t, contains('referrer=invite%3DABCD2345'));
    });

    test('invite works without a code (offline)', () {
      expect(buildInviteShare(null), endsWith(storeUrl));
    });
  });

  test('player level matches XP thresholds', () {
    for (final (xp, level) in [(0, 1), (119, 1), (120, 2), (359, 2), (360, 3), (720, 4), (5000, 9)]) {
      final d = PlayerData()..xp = xp;
      expect(d.playerLevel, level, reason: 'xp $xp');
      expect(d.levelProgress, inInclusiveRange(0, 1));
      expect(xp >= PlayerData.xpForLevel(level) && xp < PlayerData.xpForLevel(level + 1), isTrue);
    }
  });

  test('daily featured puzzle rotates through every game without back-to-back repeats', () {
    final start = DateTime.utc(2026, 1, 1, 12);
    final seen = <GameType>{};
    GameType? prev;
    for (var i = 0; i < 60; i++) {
      final g = dailyFeatured(start.add(Duration(days: i)));
      expect(g, isNot(prev), reason: 'day $i repeats');
      prev = g;
      seen.add(g);
    }
    expect(seen, GameType.values.toSet());
    expect(dailyFeatured(DateTime.utc(2026, 10, 17, 1)), dailyFeatured(DateTime.utc(2026, 10, 17, 23)));
  });

  test('level tracks unlock in order and difficulties open with stars', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlayerStore(await SharedPreferences.getInstance());
    addTearDown(store.dispose);
    const g = GameType.sudoku;
    expect(store.nextStage(g, Difficulty.easy), 1);
    expect(store.stageUnlocked(g, Difficulty.easy, 2), isFalse);
    expect(store.difficultyUnlocked(g, Difficulty.easy), isTrue);
    expect(store.difficultyUnlocked(g, Difficulty.medium), isFalse);

    final first = store.completeStage(game: g, difficulty: Difficulty.easy, stage: 1, stars: 2, durationMs: 1000);
    expect(first.firstClear, isTrue);
    expect(store.nextStage(g, Difficulty.easy), 2);
    // Replaying with more stars improves the record; fewer stars never lowers it.
    store.completeStage(game: g, difficulty: Difficulty.easy, stage: 1, stars: 3, durationMs: 900);
    final worse = store.completeStage(game: g, difficulty: Difficulty.easy, stage: 1, stars: 1, durationMs: 900);
    expect(worse.newBest, isFalse);
    expect(store.stageStars(g, Difficulty.easy, 1), 3);

    for (var n = 2; n <= 4; n++) {
      store.completeStage(game: g, difficulty: Difficulty.easy, stage: n, stars: 3, durationMs: 1000);
    }
    expect(store.trackStars(g, Difficulty.easy), 12);
    expect(store.difficultyUnlocked(g, Difficulty.medium), isTrue, reason: '10 stars in Easy opens Medium');
    expect(store.difficultyUnlocked(GameType.connect, Difficulty.medium), isFalse, reason: 'tracks are per puzzle');
  });

  test('a level is the same puzzle every time', () {
    final a = PlayRequest.stage(GameType.queens, Difficulty.hard, 12);
    final b = PlayRequest.stage(GameType.queens, Difficulty.hard, 12);
    expect(a.seed, b.seed);
    expect(PlayRequest.stage(GameType.queens, Difficulty.hard, 13).seed, isNot(a.seed));
    expect(a.title, 'Level 12');
  });
}
