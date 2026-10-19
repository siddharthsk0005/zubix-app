import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/brand_api.dart';
import '../auth/brand_session.dart';
import 'brand_profile_form.dart';

/// Brand partner sign-in, plus registration with the brand details form.
class BrandAuthScreen extends StatefulWidget {
  const BrandAuthScreen({super.key, required this.api, required this.session});

  final BrandApi api;
  final BrandSession session;

  @override
  State<BrandAuthScreen> createState() => _BrandAuthScreenState();
}

class _BrandAuthScreenState extends State<BrandAuthScreen> {
  final _loginKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  bool _loadingCategories = true;
  String? _loginError;
  String? _loadError;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _loadError = null;
    });
    try {
      _categories = await widget.api.categories();
    } on ApiException catch (e) {
      _loadError = e.message;
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _loginError = null;
    });
    try {
      final json = await widget.api.login(email, _password.text);
      widget.session.start(json['token'] as String, email);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loginError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Errors propagate to the form, which shows them inline.
  Future<void> _register(Map<String, Object?> body) async {
    final json = await widget.api.register(body);
    widget.session.start(json['token'] as String, body['email'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Brand partner',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign in')),
                    ButtonSegment(value: true, label: Text('Register')),
                  ],
                  selected: {_registering},
                  onSelectionChanged: (s) => setState(() => _registering = s.first),
                ),
                const SizedBox(height: 24),
                _registering ? _registerView() : _loginView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginView() {
    return Form(
      key: _loginKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
            onFieldSubmitted: (_) => _login(),
          ),
          if (_loginError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_loginError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _login,
            child: Text(_busy ? 'Signing in…' : 'Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _registerView() {
    if (_loadingCategories) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Column(
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          TextButton(onPressed: _loadCategories, child: const Text('Try again')),
        ],
      );
    }
    return BrandProfileForm(
      categories: _categories,
      withCredentials: true,
      submitLabel: 'Create brand account',
      onSubmit: _register,
    );
  }
}
