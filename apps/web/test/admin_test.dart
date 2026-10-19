import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubix_web/api/admin_api.dart';
import 'package:zubix_web/api/api_client.dart';
import 'package:zubix_web/auth/admin_session.dart';
import 'package:zubix_web/screens/login_screen.dart';

AdminApi _apiWith(http.Client client) =>
    AdminApi(ApiClient(httpClient: client, baseUrl: 'http://test'));

void main() {
  test('login sends email and password and returns the token', () async {
    final api = _apiWith(MockClient((request) async {
      expect(request.url.path, '/admin/auth/login');
      expect(jsonDecode(request.body), {'email': 'a@b.com', 'password': 'secret-pass'});
      return http.Response(jsonEncode({'token': 'tok'}), 200);
    }));
    final json = await api.login('a@b.com', 'secret-pass');
    expect(json['token'], 'tok');
  });

  test('authenticated calls send the bearer token', () async {
    String? seen;
    final api = _apiWith(MockClient((request) async {
      seen = request.headers['Authorization'];
      return http.Response(jsonEncode({'users': []}), 200);
    }));
    await api.listUsers('tok', status: 'PENDING');
    expect(seen, 'Bearer tok');
  });

  test('API errors surface the backend message and code', () async {
    final api = _apiWith(MockClient((_) async => http.Response(
          jsonEncode({'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Email or password is incorrect'}}),
          401,
        )));
    expect(
      () => api.login('a@b.com', 'wrong-password'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'INVALID_CREDENTIALS')
          .having((e) => e.message, 'message', 'Email or password is incorrect')),
    );
  });

  testWidgets('login screen shows the backend error on bad credentials', (tester) async {
    final api = _apiWith(MockClient((_) async => http.Response(
          jsonEncode({'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Email or password is incorrect'}}),
          401,
        )));
    final session = AdminSession();

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(api: api, session: session),
    ));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect'), findsOneWidget);
    expect(session.isSignedIn, isFalse);
  });

  testWidgets('login screen validates empty fields without calling the API', (tester) async {
    var called = false;
    final api = _apiWith(MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    }));

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(api: api, session: AdminSession()),
    ));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(called, isFalse);
  });
}
