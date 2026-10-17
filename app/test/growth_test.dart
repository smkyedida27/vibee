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
}
