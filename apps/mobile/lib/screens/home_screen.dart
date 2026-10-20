import 'package:flutter/material.dart';

import '../auth/auth_state.dart';
import '../shopper/format.dart';
import '../shopper/shopper_api.dart';
import '../shopper/shopper_models.dart';
import '../theme/app_theme.dart';
import '../widgets/centered_content.dart';
import 'auth_widgets.dart';
import 'my_coupons_screen.dart';
import 'session_detail_screen.dart';

/// Live and upcoming sessions for approved shoppers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.auth, this.api});

  final AuthState auth;

  /// Injected in tests. Defaults to the signed-in user's API.
  final ShopperApi? api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ShopperApi _api =
      widget.api ?? ShopperApi(widget.auth.authedRequest);
  late Future<SessionList> _future = _api.listSessions();

  Future<void> _refresh() async {
    setState(() => _future = _api.listSessions());
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  Future<void> _open(ShopSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(api: _api, sessionId: session.id),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openCoupons() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyCouponsScreen(api: _api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zubix'),
        actions: [
          IconButton(
            tooltip: 'My coupons',
            onPressed: _openCoupons,
            icon: const Icon(Icons.confirmation_number_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: CenteredContent(
          child: RefreshIndicator(
            color: AppColors.black,
            onRefresh: _refresh,
            child: FutureBuilder<SessionList>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _message(
                    const CircularProgressIndicator(color: AppColors.black),
                  );
                }
                if (snapshot.hasError) {
                  return _message(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(messageFor(snapshot.error!)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }
                final sessions = snapshot.data!.sessions;
                if (sessions.isEmpty) {
                  return _message(
                    const Text(
                      'No live sessions right now. Pull down to refresh.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _SessionCard(
                    session: sessions[index],
                    onTap: () => _open(sessions[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Keeps pull-to-refresh working even when there is nothing to scroll.
  Widget _message(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 320,
          child: Center(
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final ShopSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = session.status == 'LIVE'
        ? 'Live now · ${session.couponsLeft} left'
        : 'Starts ${formatWhen(context, session.startsAt)}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.grey300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: onTap,
        title: Text(
          session.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${session.brandName} · $detail'),
        ),
        trailing: Text(
          '${session.discountPercent}% off',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}
