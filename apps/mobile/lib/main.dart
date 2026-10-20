import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'auth/auth_state.dart';
import 'auth/token_store.dart';
import 'screens/pending_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/shopper_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ZubixApp());
}

class ZubixApp extends StatefulWidget {
  const ZubixApp({super.key, this.auth});

  /// Injected in tests. The app creates its own state when this is null.
  final AuthState? auth;

  @override
  State<ZubixApp> createState() => _ZubixAppState();
}

class _ZubixAppState extends State<ZubixApp> {
  late final AuthState _auth;

  @override
  void initState() {
    super.initState();
    _auth =
        widget.auth ?? AuthState(api: ApiClient(), tokenStore: TokenStore());
    _auth.restore();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zubix',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => _screenFor(_auth),
      ),
    );
  }

  Widget _screenFor(AuthState auth) {
    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.black)),
      ),
      AuthStatus.signedOut => PhoneScreen(auth: auth),
      AuthStatus.pending => PendingScreen(auth: auth, rejected: false),
      AuthStatus.rejected => PendingScreen(auth: auth, rejected: true),
      AuthStatus.approved => ShopperShell(auth: auth),
    };
  }
}
