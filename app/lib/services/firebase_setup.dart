import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'analytics.dart';
import 'api_client.dart';

/// Firebase is optional: without `google-services.json` (local dev, web, tests) every
/// call here is a no-op and the app runs exactly as before.
class FirebaseSetup {
  static bool ready = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      ready = true;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);
    } catch (e) {
      debugPrint('Firebase disabled: $e');
    }
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    if (ready) FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  static void recordError(Object error, StackTrace stack) {
    if (ready) unawaited(FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
  }

  static void setUser(String? userId) {
    if (ready && userId != null) unawaited(FirebaseCrashlytics.instance.setUserIdentifier(userId));
  }

  static StreamSubscription<String>? _tokenSub;

  /// Asks for notification permission (Android 13+ shows a prompt) and registers the FCM
  /// token with the API. Call when the player turns reminders on.
  static Future<bool> enablePush(ApiClient api) async {
    if (!ready) return false;
    final m = FirebaseMessaging.instance;
    final settings = await m.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return false;
    await _register(api);
    return true;
  }

  /// Re-registers the token on launch for players who already allowed reminders.
  static Future<void> refreshPush(ApiClient api) async {
    if (!ready) return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) await _register(api);
  }

  static Future<void> _register(ApiClient api) async {
    final m = FirebaseMessaging.instance;
    final token = await m.getToken();
    if (token != null) await api.registerPushToken(token);
    _tokenSub ??= m.onTokenRefresh.listen((t) => api.registerPushToken(t).catchError((Object _) {}));
  }
}

/// Forwards product events to Google Analytics for Firebase.
class FirebaseAnalyticsSink implements AnalyticsSink {
  @override
  void log(String event, Map<String, Object> params) {
    // Firebase accepts only String and num parameter values.
    final clean = params.map((k, v) => MapEntry(k, v is bool ? (v ? 1 : 0) : (v is num || v is String ? v : '$v')));
    unawaited(FirebaseAnalytics.instance.logEvent(name: event, parameters: clean));
  }
}
