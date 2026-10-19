import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubix_mobile/api/api_client.dart';
import 'package:zubix_mobile/auth/auth_state.dart';
import 'package:zubix_mobile/auth/token_store.dart';

class MemoryTokenStore extends TokenStore {
  String? value;

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

AuthState _authWith(
  MemoryTokenStore store,
  Future<http.Response> Function(http.Request request) handler,
) {
  final client = MockClient((request) => handler(request));
  return AuthState(
    api: ApiClient(httpClient: client, baseUrl: 'http://test'),
    tokenStore: store,
  );
}

void main() {
  test('signed out when no token is stored', () async {
    final store = MemoryTokenStore();
    final auth = _authWith(store, (_) async => fail('should not call API'));

    await auth.restore();

    expect(auth.status, AuthStatus.signedOut);
  });

  test('approved user goes to home on restore', () async {
    final store = MemoryTokenStore()..value = 'tok';
    final auth = _authWith(store, (request) async {
      expect(request.headers['Authorization'], 'Bearer tok');
      return _json({
        'user': {
          'id': 'u1',
          'phone': '+919000000001',
          'role': 'USER',
          'status': 'APPROVED',
          'name': null,
        },
      });
    });

    await auth.restore();

    expect(auth.status, AuthStatus.approved);
    expect(auth.user?.id, 'u1');
  });

  test('pending user stays on the pending screen', () async {
    final store = MemoryTokenStore()..value = 'tok';
    final auth = _authWith(store, (_) async {
      return _json({
        'user': {'id': 'u1', 'phone': null, 'role': 'USER', 'status': 'PENDING'},
      });
    });

    await auth.restore();

    expect(auth.status, AuthStatus.pending);
  });

  test('an invalid token clears the session', () async {
    final store = MemoryTokenStore()..value = 'expired';
    final auth = _authWith(store, (_) async {
      return _json({'error': {'code': 'UNAUTHORIZED', 'message': 'Sign in again.'}}, 401);
    });

    await auth.restore();

    expect(auth.status, AuthStatus.signedOut);
    expect(store.value, isNull);
  });

  test('a network failure keeps the token', () async {
    final store = MemoryTokenStore()..value = 'tok';
    final auth = _authWith(store, (_) async => throw http.ClientException('offline'));

    await auth.restore();

    expect(auth.status, AuthStatus.signedOut);
    expect(store.value, 'tok');
  });

  test('verifying the OTP stores the token and sets the status', () async {
    final store = MemoryTokenStore();
    final auth = _authWith(store, (request) async {
      expect(jsonDecode(request.body), {'phone': '+919000000001', 'code': '9001'});
      return _json({
        'token': 'new-token',
        'user': {'id': 'u1', 'phone': '+919000000001', 'role': 'USER', 'status': 'APPROVED'},
      });
    });

    await auth.verifyOtp('+919000000001', '9001');

    expect(store.value, 'new-token');
    expect(auth.status, AuthStatus.approved);
  });

  test('a wrong code surfaces the API message and changes nothing', () async {
    final store = MemoryTokenStore();
    final auth = _authWith(store, (_) async {
      return _json({'error': {'code': 'INVALID_OTP', 'message': 'Wrong code.'}}, 401);
    });

    await expectLater(
      auth.verifyOtp('+919000000001', '0000'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Wrong code.')),
    );
    expect(store.value, isNull);
    expect(auth.status, AuthStatus.unknown);
  });
}
