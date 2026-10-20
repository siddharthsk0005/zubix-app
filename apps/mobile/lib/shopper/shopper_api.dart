import 'location.dart';
import 'shopper_models.dart';

/// Sends an authenticated request. [AuthState.authedRequest] has this shape.
typedef AuthedRequest =
    Future<Map<String, dynamic>> Function(
      String method,
      String path, {
      Map<String, dynamic>? body,
    });

class SessionList {
  const SessionList({required this.serverTime, required this.sessions});

  final DateTime serverTime;
  final List<ShopSession> sessions;
}

class SessionDetail {
  const SessionDetail({required this.serverTime, required this.session});

  final DateTime serverTime;
  final ShopSession session;
}

class ClaimStart {
  const ClaimStart({required this.readyAt, required this.serverTime});

  final DateTime readyAt;
  final DateTime serverTime;
}

class ShopperApi {
  ShopperApi(this._request);

  final AuthedRequest _request;

  Future<SessionList> listSessions({
    String? kind,
    ShopperLocation? location,
  }) async {
    final query = <String, String>{
      'kind': ?kind,
      if (location != null) ...{
        'latitude': '${location.latitude}',
        'longitude': '${location.longitude}',
      },
    };
    final path = query.isEmpty
        ? '/sessions'
        : Uri(path: '/sessions', queryParameters: query).toString();
    final data = await _request('GET', path);
    return SessionList(
      serverTime: DateTime.parse(data['serverTime'] as String),
      sessions: _sessions(data['sessions'] as List<dynamic>),
    );
  }

  Future<SessionDetail> getSession(String id) async {
    final data = await _request('GET', '/sessions/$id');
    return SessionDetail(
      serverTime: DateTime.parse(data['serverTime'] as String),
      session: ShopSession.fromJson(data['session'] as Map<String, dynamic>),
    );
  }

  /// Starts the countdown. Calling it again returns the same ready time.
  Future<ClaimStart> startClaim(String sessionId) async {
    final data = await _request('POST', '/sessions/$sessionId/claim/start');
    return ClaimStart(
      readyAt: DateTime.parse(data['readyAt'] as String),
      serverTime: DateTime.parse(data['serverTime'] as String),
    );
  }

  Future<Coupon> claim(String sessionId) async {
    final data = await _request('POST', '/sessions/$sessionId/claim');
    return Coupon.fromJson(data['coupon'] as Map<String, dynamic>);
  }

  Future<List<MyCouponEntry>> myCoupons() async {
    final data = await _request('GET', '/coupons/me');
    return (data['coupons'] as List<dynamic>)
        .map((item) => MyCouponEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<ShopSession> _sessions(List<dynamic> items) => items
      .map((item) => ShopSession.fromJson(item as Map<String, dynamic>))
      .toList();
}
