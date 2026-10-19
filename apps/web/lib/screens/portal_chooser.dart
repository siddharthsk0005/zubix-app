import 'package:flutter/material.dart';

/// Which sign-in the visitor picked on the landing screen.
enum Portal { brand, admin }

/// First screen: choose between the brand partner portal and the admin panel.
class PortalChooser extends StatelessWidget {
  const PortalChooser({super.key, required this.onChoose});

  final ValueChanged<Portal> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Zubix', style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to sign in',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => onChoose(Portal.brand),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Brand partner'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => onChoose(Portal.admin),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Admin'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Brands register with their GSTIN. Admins sign in with their admin account.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
