import 'package:flutter/material.dart';

import '../auth/auth_state.dart';
import 'auth_widgets.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.auth, required this.phone});

  final AuthState auth;
  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.verifyOtp(widget.phone, _controller.text.trim());
      // The root widget switches screens on auth status, so pop this route.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Enter the code sent to ${widget.phone}',
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Code'),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(_busy ? 'Verifying...' : 'Verify'),
        ),
        ErrorText(_error),
      ],
    );
  }
}
