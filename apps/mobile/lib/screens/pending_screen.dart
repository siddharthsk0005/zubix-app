import 'package:flutter/material.dart';

import '../auth/auth_state.dart';
import 'auth_widgets.dart';

/// Shown to signed-in users whose account is not approved yet.
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key, required this.auth, required this.rejected});

  final AuthState auth;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: rejected ? 'Account not approved' : 'Awaiting approval',
      children: [
        Text(
          rejected
              ? 'Your registration was not approved. Contact Zubix support for help.'
              : 'Thanks for signing up. Your account is waiting for approval. '
                  'We will let you know once it is ready.',
        ),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: auth.signOut, child: const Text('Sign out')),
      ],
    );
  }
}
