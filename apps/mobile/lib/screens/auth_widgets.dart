import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';

/// Keeps auth screens at a readable width on tablets and web.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zubix')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown under a field or button when a request fails.
class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message!,
        style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Google and Apple sign-in, shown but disabled until credentials are configured.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider()),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')),
            Expanded(child: Divider()),
          ],
        ),
        SizedBox(height: 24),
        OutlinedButton(onPressed: null, child: Text('Continue with Google')),
        SizedBox(height: 12),
        OutlinedButton(onPressed: null, child: Text('Continue with Apple')),
      ],
    );
  }
}

String messageFor(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
