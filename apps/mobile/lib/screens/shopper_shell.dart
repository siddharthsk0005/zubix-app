import 'package:flutter/material.dart';

import '../auth/auth_state.dart';
import '../shopper/location.dart';
import '../shopper/shopper_api.dart';
import 'home_screen.dart';
import 'my_coupons_screen.dart';
import 'profile_screen.dart';

/// Phones get a bottom bar. Tablets and web get a side rail.
const _railBreakpoint = 720.0;

/// Bottom navigation for approved shoppers: Brands, Nearby, Coupons, Profile.
class ShopperShell extends StatefulWidget {
  const ShopperShell({super.key, required this.auth, this.api, this.location});

  final AuthState auth;

  /// Injected in tests. Defaults to the signed-in user's API.
  final ShopperApi? api;

  /// Injected in tests. Defaults to the device location.
  final LocationSource? location;

  @override
  State<ShopperShell> createState() => _ShopperShellState();
}

class _ShopperShellState extends State<ShopperShell> {
  late final ShopperApi _api =
      widget.api ?? ShopperApi(widget.auth.authedRequest);
  int _index = 0;

  /// Each tab is built the first time it is opened, so Nearby only asks for location when needed.
  final Set<int> _visited = {0};

  static const _destinations =
      <({String label, IconData icon, IconData selected})>[
        (
          label: 'Brands',
          icon: Icons.storefront_outlined,
          selected: Icons.storefront,
        ),
        (
          label: 'Nearby',
          icon: Icons.near_me_outlined,
          selected: Icons.near_me,
        ),
        (
          label: 'Coupons',
          icon: Icons.confirmation_number_outlined,
          selected: Icons.confirmation_number,
        ),
        (label: 'Profile', icon: Icons.person_outline, selected: Icons.person),
      ];

  void _select(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  Widget _tab(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => HomeScreen(auth: widget.auth, api: _api, location: widget.location),
      1 => HomeScreen(
        auth: widget.auth,
        api: _api,
        nearby: true,
        location: widget.location,
      ),
      2 => MyCouponsScreen(api: _api),
      _ => ProfileScreen(auth: widget.auth),
    };
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [for (var i = 0; i < _destinations.length; i++) _tab(i)],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _railBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selected),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              for (final item in _destinations)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selected),
                  label: item.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
