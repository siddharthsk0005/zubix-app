import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/brand_api.dart';
import '../auth/brand_session.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/status_chip.dart';
import 'brand_profile_form.dart';
import 'brand_sessions_screen.dart';

/// Signed-in brand layout: dashboard, profile, and sessions.
class BrandShell extends StatefulWidget {
  const BrandShell({super.key, required this.api, required this.session});

  final BrandApi api;
  final BrandSession session;

  @override
  State<BrandShell> createState() => _BrandShellState();
}

class _BrandShellState extends State<BrandShell> {
  int _index = 0;
  bool _loading = true;
  String? _loadError;
  Map<String, dynamic>? _brand;
  List<Map<String, dynamic>> _categories = [];

  String get _token => widget.session.token!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final brand = await widget.api.me(_token);
      final categories = await widget.api.categories();
      if (!mounted) return;
      _brand = brand;
      _categories = categories;
    } on ApiException catch (e) {
      // An expired or revoked token signs the brand out.
      if (e.statusCode == 401) {
        widget.session.end();
        return;
      }
      _loadError = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile(Map<String, Object?> body) async {
    final brand = await widget.api.updateProfile(_token, body);
    if (!mounted) return;
    setState(() => _brand = brand);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final brand = _brand;
    if (brand == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError ?? 'Could not load your brand.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
              TextButton(
                onPressed: widget.session.end,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }

    final sections = <Widget>[
      _Dashboard(brand: brand, onRefresh: _load),
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Brand profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              BrandProfileForm(
                categories: _categories,
                initial: brand,
                submitLabel: 'Save changes',
                onSubmit: _saveProfile,
              ),
            ],
          ),
        ),
      ),
      BrandSessionsScreen(
        api: widget.api,
        token: _token,
        canRequest: brand['status'] == 'APPROVED',
      ),
    ];

    return DashboardScaffold(
      destinations: const [
        DashboardDestination(Icons.dashboard_outlined, 'Dashboard'),
        DashboardDestination(Icons.storefront_outlined, 'Profile'),
        DashboardDestination(Icons.event_outlined, 'Sessions'),
      ],
      selectedIndex: _index,
      onSelect: (i) => setState(() => _index = i),
      email: widget.session.email ?? '',
      onSignOut: widget.session.end,
      body: sections[_index],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.brand, required this.onRefresh});

  final Map<String, dynamic> brand;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = brand['status'] as String;
    final note = brand['reviewNote'] as String?;
    final reason = (note == null || note.isEmpty) ? 'no reason given' : note;
    final (heading, message) = switch (status) {
      'APPROVED' => (
        'You are approved',
        'You can now request coupon sessions from the Sessions tab.',
      ),
      'REJECTED' => (
        'Registration rejected',
        'Reason: $reason.\nUpdate your details under Profile. Changing your GSTIN sends your brand back for review.',
      ),
      _ => (
        'Under review',
        'Our team is checking your GSTIN and details. You can complete your profile now. Session requests open after approval.',
      ),
    };
    final category =
        (brand['category'] as Map<String, dynamic>?)?['name'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    brand['name'] as String,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.grey300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusChip(status),
                      const SizedBox(width: 12),
                      Text(heading, style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(message),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _InfoRow('Founder', brand['founderName'] as String?),
            _InfoRow(
              'Business type',
              brand['kind'] == 'LOCAL_STORE' ? 'Local store' : 'Online',
            ),
            _InfoRow('Category', category),
            _InfoRow('GSTIN', brand['gstin'] as String?),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value ?? '-')),
        ],
      ),
    );
  }
}
