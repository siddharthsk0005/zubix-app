import 'package:flutter/material.dart';

import 'api/admin_api.dart';
import 'api/api_client.dart';
import 'api/brand_api.dart';
import 'auth/admin_session.dart';
import 'auth/brand_session.dart';
import 'screens/admin_shell.dart';
import 'screens/brand_auth_screen.dart';
import 'screens/brand_shell.dart';
import 'screens/login_screen.dart';
import 'screens/portal_chooser.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ZubixWebApp());
}

class ZubixWebApp extends StatefulWidget {
  const ZubixWebApp({super.key});

  @override
  State<ZubixWebApp> createState() => _ZubixWebAppState();
}

class _ZubixWebAppState extends State<ZubixWebApp> {
  final _adminSession = AdminSession();
  final _brandSession = BrandSession();
  final _client = ApiClient();
  late final _adminApi = AdminApi(_client);
  late final _brandApi = BrandApi(_client);

  Portal? _portal;

  @override
  void dispose() {
    _adminSession.dispose();
    _brandSession.dispose();
    _client.close();
    super.dispose();
  }

  Widget _home() {
    if (_adminSession.isSignedIn) {
      return AdminShell(api: _adminApi, session: _adminSession);
    }
    if (_brandSession.isSignedIn) {
      return BrandShell(api: _brandApi, session: _brandSession);
    }
    final portal = _portal;
    if (portal == null) {
      return PortalChooser(onChoose: (p) => setState(() => _portal = p));
    }
    final login = switch (portal) {
      Portal.admin => LoginScreen(api: _adminApi, session: _adminSession),
      Portal.brand => BrandAuthScreen(api: _brandApi, session: _brandSession),
    };
    return Stack(
      children: [
        login,
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _portal = null),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zubix',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: ListenableBuilder(
        listenable: Listenable.merge([_adminSession, _brandSession]),
        builder: (context, _) => _home(),
      ),
    );
  }
}
