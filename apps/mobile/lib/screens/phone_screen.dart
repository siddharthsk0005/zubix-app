import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_state.dart';
import 'auth_widgets.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, required this.auth});

  final AuthState auth;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _controller.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.requestOtp(phone);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(auth: widget.auth, phone: phone)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in',
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile number',
            hintText: '+91 90000 00001',
          ),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _sendCode,
          child: Text(_busy ? 'Sending...' : 'Send code'),
        ),
        ErrorText(_error),
        if (kDebugMode) ...[
          const SizedBox(height: 16),
          const Text('Demo mode: the code is 9001.'),
        ],
        const SocialSignInButtons(),
      ],
    );
  }
}
