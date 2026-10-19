import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zubix_mobile/api/api_client.dart';
import 'package:zubix_mobile/auth/auth_state.dart';
import 'package:zubix_mobile/auth/token_store.dart';
import 'package:zubix_mobile/main.dart';

class _MemoryTokenStore extends TokenStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('signed-out users see the phone sign-in screen', (tester) async {
    final auth = AuthState(
      api: ApiClient(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://test',
      ),
      tokenStore: _MemoryTokenStore(),
    );

    await tester.pumpWidget(ZubixApp(auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });
}
