import 'package:flutter/foundation.dart';

/// Holds the signed-in admin for this browser tab. Cleared on reload.
class AdminSession extends ChangeNotifier {
  String? _token;
  String? _email;

  bool get isSignedIn => _token != null;
  String? get token => _token;
  String? get email => _email;

  void start(String token, String email) {
    _token = token;
    _email = email;
    notifyListeners();
  }

  void end() {
    _token = null;
    _email = null;
    notifyListeners();
  }
}
