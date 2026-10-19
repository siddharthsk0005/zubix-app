import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubix_mobile/api/api_client.dart';
import 'package:zubix_mobile/auth/auth_state.dart';
import 'package:zubix_mobile/auth/token_store.dart';
import 'package:zubix_mobile/shopper/server_clock.dart';
import 'package:zubix_mobile/shopper/shopper_api.dart';

class _MemoryTokenStore extends TokenStore {
  String? value = 'tok';

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _session({String status = 'LIVE', Object? myCoupon, Object? readyAt}) => {
      'id': 's1',
      'title': 'Lunch deal',
      'createdByTag': 'Lunch',
      'status': status,
      'discountPercent': 20,
      'startsAt': '2026-01-01T10:00:00.000Z',
      'endsAt': '2026-01-01T12:00:00.000Z',
      'couponExpiresAt': '2026-01-01T13:00:00.000Z',
      'waitingSeconds': 30,
      'couponsLeft': 3,
      'brand': {'id': 'b1', 'name': 'Cafe', 'kind': 'ONLINE'},
      'category': null,
      'myCoupon': myCoupon,
      'claimReadyAt': readyAt,
    };

ShopperApi _apiWith(
  Future<http.Response> Function(http.Request request) handler, {
  _MemoryTokenStore? store,
}) {
  final auth = AuthState(
    api: ApiClient(httpClient: MockClient(handler), baseUrl: 'http://test'),
    tokenStore: store ?? _MemoryTokenStore(),
  );
  return ShopperApi(auth.authedRequest);
}

void main() {
  group('ServerClock', () {
    test('counts down to a target on the server clock', () {
      // The server says 10:00:00, and the phone reads 09:00:00 at that moment.
      final clock = ServerClock(
        DateTime.utc(2026, 1, 1, 10),
        localNow: DateTime.utc(2026, 1, 1, 9),
      );
      final target = DateTime.utc(2026, 1, 1, 10, 0, 30);

      expect(clock.secondsUntil(target, localNow: DateTime.utc(2026, 1, 1, 9)), 30);
      expect(clock.secondsUntil(target, localNow: DateTime.utc(2026, 1, 1, 9, 0, 20)), 10);
    });

    test('rounds partial seconds up and never goes negative', () {
      final clock = ServerClock(
        DateTime.utc(2026, 1, 1, 10),
        localNow: DateTime.utc(2026, 1, 1, 10),
      );
      final target = DateTime.utc(2026, 1, 1, 10, 0, 1, 500);

      final localNow = DateTime.utc(2026, 1, 1, 10);

      expect(clock.secondsUntil(target, localNow: localNow), 2);
      expect(clock.secondsUntil(DateTime.utc(2026, 1, 1, 9), localNow: localNow), 0);
    });
  });

  group('ShopperApi', () {
    test('lists sessions with the bearer token', () async {
      final api = _apiWith((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/sessions');
        expect(request.headers['Authorization'], startsWith('Bearer '));
        return _json({
          'serverTime': '2026-01-01T10:00:00.000Z',
          'sessions': [_session()],
        });
      });

      final list = await api.listSessions();

      expect(list.sessions, hasLength(1));
      final session = list.sessions.single;
      expect(session.title, 'Lunch deal');
      expect(session.brandName, 'Cafe');
      expect(session.discountPercent, 20);
      expect(session.couponsLeft, 3);
      expect(session.myCoupon, isNull);
      expect(session.claimReadyAt, isNull);
    });

    test('startClaim returns the ready time from the server', () async {
      final api = _apiWith((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/sessions/s1/claim/start');
        return _json({
          'readyAt': '2026-01-01T10:00:30.000Z',
          'serverTime': '2026-01-01T10:00:00.000Z',
          'waitingSeconds': 30,
        });
      });

      final start = await api.startClaim('s1');

      expect(start.readyAt, DateTime.utc(2026, 1, 1, 10, 0, 30));
      expect(start.serverTime, DateTime.utc(2026, 1, 1, 10));
    });

    test('claim returns the coupon', () async {
      final api = _apiWith((request) async {
        expect(request.url.path, '/sessions/s1/claim');
        return _json({
          'coupon': {
            'id': 'c1',
            'code': 'ZB-ABCD-EFGH',
            'status': 'CLAIMED',
            'expiresAt': '2026-01-01T13:00:00.000Z',
          },
        });
      });

      final coupon = await api.claim('s1');

      expect(coupon.code, 'ZB-ABCD-EFGH');
      expect(coupon.status, 'CLAIMED');
    });

    test('claim surfaces server error codes', () async {
      final api = _apiWith((_) async => _json({
            'error': {'code': 'SOLD_OUT', 'message': 'All coupons are gone'},
          }, 409));

      await expectLater(
        api.claim('s1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'SOLD_OUT')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('myCoupons parses the session and brand', () async {
      final api = _apiWith((request) async {
        expect(request.url.path, '/coupons/me');
        return _json({
          'serverTime': '2026-01-01T10:00:00.000Z',
          'coupons': [
            {
              'id': 'c1',
              'code': 'ZB-ABCD-EFGH',
              'status': 'CLAIMED',
              'claimedAt': '2026-01-01T10:00:31.000Z',
              'expiresAt': '2026-01-01T13:00:00.000Z',
              'session': {
                'id': 's1',
                'title': 'Lunch deal',
                'discountPercent': 20,
                'endsAt': '2026-01-01T12:00:00.000Z',
                'brand': {'name': 'Cafe'},
              },
            },
          ],
        });
      });

      final coupons = await api.myCoupons();

      expect(coupons.single.coupon.code, 'ZB-ABCD-EFGH');
      expect(coupons.single.brandName, 'Cafe');
      expect(coupons.single.sessionTitle, 'Lunch deal');
      expect(coupons.single.discountPercent, 20);
    });

    test('a 401 clears the saved session', () async {
      final store = _MemoryTokenStore();
      final api = _apiWith(
        (_) async => _json({
          'error': {'code': 'UNAUTHORIZED', 'message': 'Expired'},
        }, 401),
        store: store,
      );

      await expectLater(api.listSessions(), throwsA(isA<ApiException>()));
      expect(store.value, isNull);
    });
  });
}
