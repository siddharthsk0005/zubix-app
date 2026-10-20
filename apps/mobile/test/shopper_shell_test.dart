import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubix_mobile/api/api_client.dart';
import 'package:zubix_mobile/auth/auth_state.dart';
import 'package:zubix_mobile/auth/token_store.dart';
import 'package:zubix_mobile/screens/shopper_shell.dart';
import 'package:zubix_mobile/shopper/location.dart';

class _MemoryTokenStore extends TokenStore {
  String? value = 'tok';

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

class _FakeLocation implements LocationSource {
  int calls = 0;

  @override
  Future<ShopperLocation> current() async {
    calls++;
    return const ShopperLocation(51.5, -0.12);
  }
}

class _RecordingHttp {
  final List<String> paths = [];

  Future<http.Response> handle(http.Request request) async {
    paths.add(request.url.toString());
    return http.Response(
      jsonEncode(const <Object>[]),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<(_RecordingHttp, _FakeLocation)> _pump(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);

  final recorder = _RecordingHttp();
  final location = _FakeLocation();
  final auth = AuthState(
    api: ApiClient(
      httpClient: MockClient(recorder.handle),
      baseUrl: 'http://test',
    ),
    tokenStore: _MemoryTokenStore(),
  );
  final shell = ShopperShell(auth: auth, location: location);
  await tester.pumpWidget(MaterialApp(home: shell));
  await tester.pump();
  return (recorder, location);
}

void main() {
  testWidgets('phones get a bottom bar with the four tabs', (tester) async {
    await _pump(tester, size: const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in ['Brands', 'Nearby', 'Coupons', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('tablets and web get a side rail instead', (tester) async {
    await _pump(tester, size: const Size(1024, 768));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Nearby asks for location and fetches LOCAL_STORE sessions', (
    tester,
  ) async {
    final (recorder, location) = await _pump(
      tester,
      size: const Size(390, 844),
    );
    expect(location.calls, 0);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Nearby'));
    await tester.pumpAndSettle();

    expect(location.calls, greaterThanOrEqualTo(1));
    expect(recorder.paths.any((p) => p.contains('kind=LOCAL_STORE')), isTrue);
  });
}
