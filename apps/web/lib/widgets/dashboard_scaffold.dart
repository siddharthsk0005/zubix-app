import 'package:flutter/material.dart';

import 'responsive.dart';

class DashboardDestination {
  const DashboardDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Signed-in layout. Wide screens get a side rail. Phones and narrow tablets get a bottom bar.
class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.email,
    required this.onSignOut,
    required this.body,
  });

  final List<DashboardDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String email;
  final VoidCallback onSignOut;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    if (!wide) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            email,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: onSignOut,
            ),
          ],
        ),
        body: SafeArea(child: body),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: onSelect,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(email, style: Theme.of(context).textTheme.labelSmall),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: onSignOut,
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
