import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../auth/admin_session.dart';
import '../util/format.dart';
import '../widgets/dashboard_scaffold.dart';
import 'categories_screen.dart';
import 'review_queue.dart';

/// Signed-in layout: side navigation plus the selected section.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.api, required this.session});

  final AdminApi api;
  final AdminSession session;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final token = widget.session.token!;
    final sections = <Widget>[
      ReviewQueue(
        key: const ValueKey('users'),
        title: 'User registrations',
        load: (status) => widget.api.listUsers(token, status: status),
        review: (id, {required approve, note}) =>
            widget.api.reviewUser(token, id, approve: approve, note: note),
        labelOf: (row) =>
            (row['name'] as String?) ?? (row['phone'] as String? ?? '-'),
        detailOf: (row) =>
            [row['phone'], row['email']].whereType<String>().join(' · '),
      ),
      ReviewQueue(
        key: const ValueKey('brands'),
        title: 'Brand registrations',
        load: (status) => widget.api.listBrands(token, status: status),
        review: (id, {required approve, note}) =>
            widget.api.reviewBrand(token, id, approve: approve, note: note),
        labelOf: (row) => (row['name'] as String?) ?? '-',
        detailOf: (row) =>
            (row['category'] as Map<String, dynamic>?)?['name'] as String? ??
            '',
      ),
      ReviewQueue(
        key: const ValueKey('sessions'),
        title: 'Coupon sessions',
        statuses: const [
          (value: 'REQUESTED', label: 'Requested'),
          (value: 'APPROVED', label: 'Approved'),
          (value: 'REJECTED', label: 'Rejected'),
        ],
        pendingStatus: 'REQUESTED',
        load: (status) => widget.api.listSessions(token, status: status),
        review: (id, {required approve, note}) =>
            widget.api.reviewSession(token, id, approve: approve, note: note),
        labelOf: (row) => (row['title'] as String?) ?? '-',
        detailOf: (row) {
          final brand =
              (row['brand'] as Map<String, dynamic>?)?['name'] as String? ??
              '-';
          final start = DateTime.parse(row['startsAt'] as String);
          final end = DateTime.parse(row['endsAt'] as String);
          return '$brand · ${formatDateTime(start)} to ${formatDateTime(end)} · '
              '${row['discountPercent']}% · ${row['couponCount']} coupons';
        },
      ),
      CategoriesScreen(api: widget.api, token: token),
    ];

    return DashboardScaffold(
      destinations: const [
        DashboardDestination(Icons.people_outline, 'Users'),
        DashboardDestination(Icons.storefront_outlined, 'Brands'),
        DashboardDestination(Icons.event_outlined, 'Sessions'),
        DashboardDestination(Icons.category_outlined, 'Categories'),
      ],
      selectedIndex: _index,
      onSelect: (i) => setState(() => _index = i),
      email: widget.session.email ?? '',
      onSignOut: widget.session.end,
      body: sections[_index],
    );
  }
}
