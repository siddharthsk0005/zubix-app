import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'token_store.dart';

enum AuthStatus { unknown, signedOut, pending, approved, rejected }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.status,
    this.name,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        phone: json['phone'] as String?,
        role: json['role'] as String,
        status: json['status'] as String,
        name: json['name'] as String?,
      );

  final String id;
  final String? phone;
  final String role;
  final String status;
  final String? name;
}

/// Owns the signed-in session and decides which screen the user sees.
class AuthState extends ChangeNotifier {
  AuthState({required ApiClient api, required TokenStore tokenStore})
      : _api = api,
        _tokens = tokenStore;

  final ApiClient _api;
  final TokenStore _tokens;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;

  AuthStatus get status => _status;
  AuthUser? get user => _user;

  /// Loads the saved token and asks the API who it belongs to.
  Future<void> restore() async {
    final token = await _tokens.read();
    if (token == null) {
      _set(AuthStatus.signedOut);
      return;
    }
    try {
      final data = await _api.get('/auth/me', token: token);
      _applyUser(AuthUser.fromJson(data['user'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _clearSession();
      } else {
        // Keep the token so a temporary outage does not sign the user out.
        _set(AuthStatus.signedOut);
      }
    }
  }

  Future<void> requestOtp(String phone) async {
    await _api.post('/auth/otp/request', body: {'phone': phone});
  }

  Future<void> verifyOtp(String phone, String code) async {
    final data = await _api.post(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code},
    );
    final token = data['token'] as String;
    await _tokens.write(token);
    _applyUser(AuthUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> signOut() => _clearSession();

  void _applyUser(AuthUser user) {
    _user = user;
    _set(switch (user.status) {
      'APPROVED' => AuthStatus.approved,
      'REJECTED' => AuthStatus.rejected,
      _ => AuthStatus.pending,
    });
  }

  Future<void> _clearSession() async {
    _user = null;
    await _tokens.clear();
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus next) {
    _status = next;
    notifyListeners();
  }
}
