import 'package:flutter/material.dart';

import '../shopper/format.dart';
import '../shopper/shopper_api.dart';
import '../shopper/shopper_models.dart';
import '../theme/app_theme.dart';
import 'auth_widgets.dart';

/// Every coupon the shopper has claimed, newest first.
class MyCouponsScreen extends StatefulWidget {
  const MyCouponsScreen({super.key, required this.api});

  final ShopperApi api;

  @override
  State<MyCouponsScreen> createState() => _MyCouponsScreenState();
}

class _MyCouponsScreenState extends State<MyCouponsScreen> {
  late Future<List<MyCouponEntry>> _future = widget.api.myCoupons();

  Future<void> _refresh() async {
    setState(() => _future = widget.api.myCoupons());
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My coupons')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.black,
          onRefresh: _refresh,
          child: FutureBuilder<List<MyCouponEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return ListView(
                  children: const [
                    SizedBox(
                      height: 320,
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.black),
                      ),
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ErrorText(messageFor(snapshot.error!)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
                  ],
                );
              }
              final coupons = snapshot.data!;
              if (coupons.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    Text('No coupons yet. Claim one from a live session.'),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: coupons.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _CouponTile(entry: coupons[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.entry});

  final MyCouponEntry entry;

  @override
  Widget build(BuildContext context) {
    final coupon = entry.coupon;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.grey300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.brandName} · ${entry.sessionTitle}'),
            const SizedBox(height: 8),
            SelectableText(
              coupon.code,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              '${entry.discountPercent}% off · ${prettyStatus(coupon.status)} · '
              'Valid until ${formatWhen(context, coupon.expiresAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
