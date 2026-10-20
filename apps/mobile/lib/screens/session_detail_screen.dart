import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../shopper/format.dart';
import '../shopper/server_clock.dart';
import '../shopper/shopper_api.dart';
import '../shopper/shopper_models.dart';
import '../theme/app_theme.dart';
import '../widgets/centered_content.dart';
import 'auth_widgets.dart';

/// Shows one session. The shopper starts a countdown, then claims the coupon.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.api,
    required this.sessionId,
  });

  final ShopperApi api;
  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  ShopSession? _session;
  Coupon? _coupon;
  ServerClock? _clock;
  DateTime? _readyAt;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.api.getSession(widget.sessionId);
      if (!mounted) return;
      final session = detail.session;
      setState(() {
        _session = session;
        _coupon = session.myCoupon;
        _clock = ServerClock(detail.serverTime);
        _readyAt = session.claimReadyAt;
      });
      _startCountdown();
    } catch (error) {
      if (mounted) setState(() => _error = messageFor(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  /// Counts down on the server clock. Ticks once a second until ready.
  void _startCountdown() {
    _timer?.cancel();
    final readyAt = _readyAt;
    final clock = _clock;
    if (readyAt == null || clock == null) return;

    void tick() {
      final left = clock.secondsUntil(readyAt);
      setState(() => _secondsLeft = left);
      if (left == 0) _timer?.cancel();
    }

    tick();
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      // The server state changed under us, so reload the session.
      if (const {
        'ALREADY_CLAIMED',
        'SESSION_NOT_LIVE',
        'COUPONS_EXPIRED',
      }.contains(error.code)) {
        await _reload();
      }
    } catch (error) {
      if (mounted) setState(() => _error = messageFor(error));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _startClaim() => _run(() async {
    final start = await widget.api.startClaim(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _clock = ServerClock(start.serverTime);
      _readyAt = start.readyAt;
    });
    _startCountdown();
  });

  Future<void> _claim() => _run(() async {
    final coupon = await widget.api.claim(widget.sessionId);
    if (!mounted) return;
    setState(() => _coupon = coupon);
  });

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Session')),
      body: SafeArea(
        child: CenteredContent(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.black),
                )
              : session == null
              ? _LoadFailed(message: _error, onRetry: _reload)
              : _SessionBody(
                  session: session,
                  coupon: _coupon,
                  secondsLeft: _secondsLeft,
                  hasCountdown: _readyAt != null,
                  busy: _busy,
                  error: _error,
                  onStart: _startClaim,
                  onClaim: _claim,
                ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message ?? 'Something went wrong. Please try again.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.session,
    required this.coupon,
    required this.secondsLeft,
    required this.hasCountdown,
    required this.busy,
    required this.error,
    required this.onStart,
    required this.onClaim,
  });

  final ShopSession session;
  final Coupon? coupon;
  final int secondsLeft;
  final bool hasCountdown;
  final bool busy;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(session.brandName, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(session.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '${session.discountPercent}% off'
          '${session.createdByTag == null ? '' : ' · ${session.createdByTag}'}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Text('Ends ${formatWhen(context, session.endsAt)}'),
        const SizedBox(height: 32),
        _action(context),
        ErrorText(error),
      ],
    );
  }

  Widget _action(BuildContext context) {
    if (coupon != null) return _CouponCard(coupon: coupon!);

    switch (session.status) {
      case 'ENDED':
        return const Text('This session has ended.');
      case 'APPROVED':
        return Text('Opens ${formatWhen(context, session.startsAt)}.');
    }

    if (session.couponsLeft == 0 && !hasCountdown) {
      return const Text(
        'Sold out.',
        style: TextStyle(fontWeight: FontWeight.w700),
      );
    }
    if (!hasCountdown) {
      return FilledButton(
        onPressed: busy ? null : onStart,
        child: const Text('Get my coupon'),
      );
    }
    if (secondsLeft > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your coupon unlocks in $secondsLeft s',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const FilledButton(onPressed: null, child: Text('Claim coupon')),
        ],
      );
    }
    return FilledButton(
      onPressed: busy ? null : onClaim,
      child: const Text('Claim coupon'),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.black, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your coupon code'),
          const SizedBox(height: 8),
          SelectableText(
            coupon.code,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Text('Valid until ${formatWhen(context, coupon.expiresAt)}'),
        ],
      ),
    );
  }
}
