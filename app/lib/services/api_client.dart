import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown for non-2xx responses; carries the RFC 7807 problem `code` when present.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.body]);
  final int status;
  final String? code;
  final String message;
  final Map<String, dynamic>? body;

  bool get isConflict => status == 409;
  bool get isOffline => status == 0;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// Thin typed client for the Puzzle Hub API (docs/CONTRACT.md).
///
/// * Creates a guest session on demand — players never have to sign up to play.
/// * Refreshes the access token once on 401 and retries.
/// * Sends `X-Request-Id` and `Idempotency-Key` where the contract requires.
class ApiClient {
  ApiClient(this._prefs, {http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

  final SharedPreferences _prefs;
  final http.Client _http;
  final String baseUrl;
  static const _timeout = Duration(seconds: 10);
  final _rand = Random.secure();

  String? get _access => _prefs.getString('auth.access');
  String? get _refresh => _prefs.getString('auth.refresh');
  String? get userId => _prefs.getString('auth.user');
  bool get hasSession => _refresh != null;

  String get deviceId {
    var id = _prefs.getString('device.id');
    if (id == null) {
      id = newId();
      _prefs.setString('device.id', id);
    }
    return id;
  }

  String newId() {
    final b = List<int>.generate(16, (_) => _rand.nextInt(256));
    b[6] = (b[6] & 0x0F) | 0x40;
    b[8] = (b[8] & 0x3F) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _storeSession(Map<String, dynamic> j) async {
    await _prefs.setString('auth.access', j['accessToken'] as String);
    await _prefs.setString('auth.refresh', j['refreshToken'] as String);
    await _prefs.setString('auth.user', '${j['userId']}');
  }

  Future<void> clearSession() async {
    await _prefs.remove('auth.access');
    await _prefs.remove('auth.refresh');
    await _prefs.remove('auth.user');
  }

  Future<void> ensureSession() async {
    if (hasSession) return;
    final j = await _send('POST', '/api/v1/auth/guest', body: {'deviceId': deviceId}, auth: false);
    await _storeSession(j as Map<String, dynamic>);
  }

  Completer<bool>? _refreshing;

  Future<bool> _refreshSession() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    try {
      final r = _refresh;
      if (r == null) {
        c.complete(false);
      } else {
        final j = await _send('POST', '/api/v1/auth/refresh', body: {'refreshToken': r}, auth: false);
        await _storeSession(j as Map<String, dynamic>);
        c.complete(true);
      }
    } on ApiException catch (e) {
      if (e.status == 401) await clearSession();
      c.complete(false);
    } finally {
      _refreshing = null;
    }
    return c.future;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
    String? idempotencyKey,
    bool retried = false,
  }) async {
    if (auth) await ensureSession();
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-Id': newId(),
      if (auth && _access != null) 'Authorization': 'Bearer $_access',
      'Idempotency-Key': ?idempotencyKey,
    };
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } on TimeoutException {
      throw ApiException(0, 'TIMEOUT', 'The server took too long to respond');
    } catch (e) {
      throw ApiException(0, 'OFFLINE', 'No connection');
    }
    if (res.statusCode == 401 && auth && !retried) {
      if (await _refreshSession()) {
        return _send(method, path, body: body, query: query, auth: auth, idempotencyKey: idempotencyKey, retried: true);
      }
      await clearSession();
      return _send(method, path, body: body, query: query, auth: auth, idempotencyKey: idempotencyKey, retried: true);
    }
    final decoded = res.body.isEmpty ? null : _tryJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    final m = decoded is Map<String, dynamic> ? decoded : null;
    throw ApiException(res.statusCode, m?['code'] as String?, (m?['detail'] ?? m?['title'] ?? 'Request failed') as String, m);
  }

  dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- endpoints
  Future<Map<String, dynamic>> dailyChallenge({String? date}) async =>
      await _send('GET', '/api/v1/daily-challenge', query: {'date': ?date}) as Map<String, dynamic>;

  Future<Map<String, dynamic>> createAttempt(String puzzleId) {
    final key = newId();
    return _send('POST', '/api/v1/attempts', body: {'puzzleId': puzzleId, 'idempotencyKey': key}, idempotencyKey: key)
        .then((v) => v as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> submitAttempt(String attemptId,
          {required Map<String, dynamic> submission, required int hintsUsed, required int clientDurationMs}) async =>
      await _send('POST', '/api/v1/attempts/$attemptId/submit', body: {
        'submission': submission,
        'hintsUsed': hintsUsed,
        'clientDurationMs': clientDurationMs,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> leaderboard({
    required String period, // daily | weekly
    String scope = 'GLOBAL',
    String? gameType,
    int page = 0,
    int size = 50,
  }) async =>
      await _send('GET', '/api/v1/leaderboards/$period', query: {
        'scope': scope,
        'gameType': ?gameType,
        'page': '$page',
        'size': '$size',
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> streak() async => await _send('GET', '/api/v1/me/streak') as Map<String, dynamic>;
  Future<Map<String, dynamic>> profile() async => await _send('GET', '/api/v1/me/profile') as Map<String, dynamic>;
  Future<void> updatePreferences(Map<String, dynamic> prefs) => _send('PATCH', '/api/v1/me/preferences', body: prefs);
  Future<Map<String, dynamic>> wallet() async => await _send('GET', '/api/v1/me/wallet') as Map<String, dynamic>;
  Future<Map<String, dynamic>> entitlements() async =>
      await _send('GET', '/api/v1/me/entitlements') as Map<String, dynamic>;

  Future<Map<String, dynamic>> spend(String sku) {
    final key = newId();
    return _send('POST', '/api/v1/me/wallet/spend', body: {'sku': sku, 'idempotencyKey': key}, idempotencyKey: key)
        .then((v) => v as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> verifyGooglePurchase(String productId, String purchaseToken) async =>
      await _send('POST', '/api/v1/purchases/google/verify',
          body: {'productId': productId, 'purchaseToken': purchaseToken}, idempotencyKey: purchaseToken) as Map<String, dynamic>;

  Future<Map<String, dynamic>?> getProgress() async => await _send('GET', '/api/v1/me/progress') as Map<String, dynamic>?;

  Future<Map<String, dynamic>> putProgress(int version, Map<String, dynamic> data) async =>
      await _send('PUT', '/api/v1/me/progress', body: {'version': version, 'data': data}) as Map<String, dynamic>;

  Future<void> addFriend(String code) => _send('POST', '/api/v1/me/friends', body: {'friendCode': code});

  Future<void> registerPushToken(String token) =>
      _send('POST', '/api/v1/me/push-token', body: {
        'token': token,
        'platform': kIsWeb ? 'WEB' : (defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID'),
      });

  Future<void> deleteAccount() async {
    await _send('DELETE', '/api/v1/me');
    await clearSession();
  }
}
