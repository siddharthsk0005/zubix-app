import 'package:flutter/material.dart';

import 'api/admin_api.dart';
import 'api/api_client.dart';
import 'auth/admin_session.dart';
import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ZubixAdminApp());
}

class ZubixAdminApp extends StatefulWidget {
  const ZubixAdminApp({super.key});

  @override
  State<ZubixAdminApp> createState() => _ZubixAdminAppState();
}

class _ZubixAdminAppState extends State<ZubixAdminApp> {
  final _session = AdminSession();
  final _api = AdminApi(ApiClient());

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zubix Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: ListenableBuilder(
        listenable: _session,
        builder: (context, _) => _session.isSignedIn
            ? AdminShell(api: _api, session: _session)
            : LoginScreen(api: _api, session: _session),
      ),
    );
  }
}
