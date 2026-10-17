import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../games/common/game_type.dart';
import '../state/player.dart';

/// One scheduled reminder.
class ReminderSlot {
  const ReminderSlot(this.at, this.title, this.body);
  final DateTime at;
  final String title;
  final String body;
}

/// Plans the next [days] daily reminders at the player's chosen local hour.
///
/// [localDay] builds the local wall-clock instant for a calendar day (time-zone aware in the
/// app, plain [DateTime] in tests). A slot is skipped when the daily puzzle it would point at
/// (puzzles roll over at UTC midnight) has already been played.
List<ReminderSlot> planReminders(
  PlayerData d,
  DateTime now, {
  int days = 7,
  DateTime Function(int y, int m, int day, int hour)? localDay,
}) {
  if (!d.settings.reminders) return const [];
  final make = localDay ?? (y, m, day, h) => DateTime(y, m, day, h);
  final out = <ReminderSlot>[];
  for (var i = 0; i <= days; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final at = make(day.year, day.month, day.day, d.settings.reminderHour);
    if (!at.isAfter(now)) continue;
    if (utcDate(at) == d.dailyDate && d.dailyDone.isNotEmpty) continue;
    if (out.length == days) break;
    final first = out.isEmpty;
    final game = GameType.values[(day.day + day.month) % GameType.values.length];
    if (first && d.streak > 1) {
      out.add(
        ReminderSlot(
          at,
          '🔥 Keep your ${d.streak}-day streak alive!',
          "Today's puzzles are ready. One quick solve keeps the flame burning.",
        ),
      );
    } else if (out.length == 3) {
      out.add(
        ReminderSlot(
          at,
          '🧩 We saved you a puzzle',
          'Your friends have been climbing the leaderboard. Jump back in with a quick ${game.title}!',
        ),
      );
    } else {
      out.add(
        ReminderSlot(
          at,
          "🧩 Today's puzzles are ready",
          'A fresh ${game.title} is waiting. Can you top the daily leaderboard?',
        ),
      );
    }
  }
  return out;
}

/// Local (on-device) daily reminders: they work offline and need no push server.
/// Rescheduled whenever the setting, reminder hour, streak or today's completion changes.
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _baseId = 100;
  static const _maxSlots = 8;
  bool _ready = false;

  /// The device's IANA time zone (e.g. `Asia/Kolkata`) once [init] has run; sent with the profile.
  String? zoneId;
  String? _lastSignature;

  bool _scheduledThisRun = false;

  /// Invoked when the player taps a reminder (the app routes to the daily screen).
  VoidCallback? onOpenDaily;
  bool _launchedFromReminder = false;

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void>? _initializing;

  /// Idempotent and safe to call concurrently.
  Future<void> init() => _initializing ??= _init();

  Future<void> _init() async {
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
        zoneId = zone.identifier;
      } catch (e) {
        debugPrint('reminders: unknown local zone, using UTC: $e');
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_puzzle'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onOpenDaily?.call(),
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      _launchedFromReminder = launch?.didNotificationLaunchApp ?? false;
      _ready = true;
    } catch (e) {
      debugPrint('reminders disabled: $e');
    }
  }

  /// True once if the app was cold-started by tapping a reminder.
  bool consumeLaunchedFromReminder() {
    final v = _launchedFromReminder;
    _launchedFromReminder = false;
    return v;
  }

  /// Shows the OS permission prompt (Android 13+, iOS). Returns whether reminders may be shown.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
    } catch (e) {
      debugPrint('reminder permission failed: $e');
      return false;
    }
  }

  /// Reschedules if anything that affects the reminders changed since the last call.
  Future<void> sync(PlayerData d, {bool force = false}) async {
    final sig =
        '${d.settings.reminders}|${d.settings.reminderHour}|${d.dailyDate}|'
        '${d.dailyDone.isNotEmpty}|${d.streak}';
    if (!force && sig == _lastSignature) return;
    _lastSignature = sig;
    // Reminders off and nothing scheduled in this app run: don't touch the native plugin at all.
    // (Turning reminders off always happens in a run that scheduled them, which cancels them.)
    if (!d.settings.reminders && !_scheduledThisRun) return;
    await init();
    if (!_ready) return;
    try {
      for (var i = 0; i < _maxSlots; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      final slots = planReminders(
        d,
        tz.TZDateTime.now(tz.local),
        localDay: (y, m, day, h) => tz.TZDateTime(tz.local, y, m, day, h),
      );
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily puzzle reminder',
          channelDescription: 'A once-a-day nudge when new puzzles are ready',
          icon: 'ic_stat_puzzle',
        ),
        iOS: DarwinNotificationDetails(),
      );
      if (slots.isNotEmpty) _scheduledThisRun = true;
      for (var i = 0; i < slots.length && i < _maxSlots; i++) {
        final s = slots[i];
        await _plugin.zonedSchedule(
          id: _baseId + i,
          scheduledDate: tz.TZDateTime.from(s.at, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: s.title,
          body: s.body,
          payload: 'daily',
        );
      }
    } catch (e) {
      _lastSignature = null;
      debugPrint('reminder schedule failed: $e');
    }
  }
}
