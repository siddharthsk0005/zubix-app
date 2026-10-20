import 'package:flutter/material.dart';

import '../auth/auth_state.dart';
import '../shopper/format.dart';
import '../shopper/location.dart';
import '../shopper/shopper_api.dart';
import '../shopper/shopper_models.dart';
import '../theme/app_theme.dart';
import '../widgets/centered_content.dart';
import 'auth_widgets.dart';
import 'session_detail_screen.dart';

/// Sessions for the Brands tab (online) or the Nearby tab (stores within radius).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    this.api,
    this.nearby = false,
    this.location,
  });

  final AuthState auth;

  /// Injected in tests. Defaults to the signed-in user's API.
  final ShopperApi? api;

  /// Shows local stores near the shopper instead of online brands.
  final bool nearby;

  /// Injected in tests. Defaults to the device location.
  final LocationSource? location;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ShopperApi _api =
      widget.api ?? ShopperApi(widget.auth.authedRequest);
  late final LocationSource _location =
      widget.location ?? GeolocatorLocationSource();
  late Future<SessionList> _future = _load();

  Future<SessionList> _load() async {
    if (!widget.nearby) return _api.listSessions(kind: 'ONLINE');
    final location = await _location.current();
    return _api.listSessions(kind: 'LOCAL_STORE', location: location);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nearby ? 'Nearby' : 'Brands')),
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
                    Text(
                      widget.nearby
                          ? 'No nearby coupons right now. Pull down to refresh.'
                          : 'No live brand sessions right now. Pull down to refresh.',
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
