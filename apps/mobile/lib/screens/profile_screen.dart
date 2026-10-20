import 'package:flutter/material.dart';

import '../auth/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/centered_content.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.auth});

  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final name = user?.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: CenteredContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.grey300,
                  child: Icon(Icons.person_outline, color: AppColors.black),
                ),
                title: Text(
                  name == null || name.isEmpty ? 'Shopper' : name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(user?.phone ?? ''),
              ),
              const Divider(height: 32),
              OutlinedButton.icon(
                onPressed: auth.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
