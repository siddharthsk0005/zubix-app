import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubix_web/api/api_client.dart';
import 'package:zubix_web/api/brand_api.dart';
import 'package:zubix_web/screens/portal_chooser.dart';

BrandApi _apiWith(http.Client client) =>
    BrandApi(ApiClient(httpClient: client, baseUrl: 'http://test'));

void main() {
  test('register posts the brand details and returns the token', () async {
    final api = _apiWith(MockClient((request) async {
      expect(request.url.path, '/brands/auth/register');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['email'], 'owner@cafe.com');
      expect(body['kind'], 'LOCAL_STORE');
      return http.Response(jsonEncode({'token': 'tok', 'brand': {}}), 201);
    }));
    final json = await api.register({
      'email': 'owner@cafe.com',
      'password': 'long-enough-pass',
      'name': 'Test Cafe',
      'founderName': 'Asha',
      'kind': 'LOCAL_STORE',
      'categoryId': 'cat-1',
      'gstin': '27AAPFU0939F1ZV',
    });
    expect(json['token'], 'tok');
  });

  test('brand calls send the bearer token', () async {
    String? seen;
    final api = _apiWith(MockClient((request) async {
      seen = request.headers['Authorization'];
      return http.Response(jsonEncode({'sessions': []}), 200);
    }));
    await api.sessions('tok');
    expect(seen, startsWith('Bearer '));
  });

  test('session errors surface the backend code and message', () async {
    final api = _apiWith(MockClient((_) async => http.Response(
          jsonEncode({'error': {'code': 'BRAND_NOT_APPROVED', 'message': 'Your brand must be approved first'}}),
          403,
        )));
    expect(
      () => api.requestSession('tok', {'title': 'Lunch'}),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'BRAND_NOT_APPROVED')
          .having((e) => e.statusCode, 'statusCode', 403)),
    );
  });

  testWidgets('portal chooser reports the selected portal', (tester) async {
    Portal? chosen;
    await tester.pumpWidget(MaterialApp(
      home: PortalChooser(onChoose: (p) => chosen = p),
    ));
    await tester.tap(find.widgetWithText(FilledButton, 'Brand partner'));
    expect(chosen, Portal.brand);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Admin'));
    expect(chosen, Portal.admin);
  });
}
