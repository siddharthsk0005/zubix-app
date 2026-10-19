import 'package:flutter/material.dart';

import '../api/api_client.dart';

typedef SubmitBrand = Future<void> Function(Map<String, Object?> body);

/// Brand details shared by registration (with login credentials) and profile edits.
/// Errors from [onSubmit] are shown inline; the backend stays the source of truth.
class BrandProfileForm extends StatefulWidget {
  const BrandProfileForm({
    super.key,
    required this.categories,
    required this.onSubmit,
    required this.submitLabel,
    this.initial,
    this.withCredentials = false,
  });

  final List<Map<String, dynamic>> categories;
  final SubmitBrand onSubmit;
  final String submitLabel;
  final Map<String, dynamic>? initial;
  final bool withCredentials;

  @override
  State<BrandProfileForm> createState() => _BrandProfileFormState();
}

class _BrandProfileFormState extends State<BrandProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _founder = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController();

  late String _kind;
  String? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? const <String, dynamic>{};
    _kind = (initial['kind'] as String?) ?? 'ONLINE';
    _categoryId = initial['categoryId'] as String?;
    _name.text = (initial['name'] as String?) ?? '';
    _founder.text = (initial['founderName'] as String?) ?? '';
    _gstin.text = (initial['gstin'] as String?) ?? '';
    _address.text = (initial['registeredAddress'] as String?) ?? '';
    _website.text = (initial['websiteUrl'] as String?) ?? '';
    _latitude.text = _numberText(initial['latitude']);
    _longitude.text = _numberText(initial['longitude']);
    _radius.text = _numberText(initial['radiusMeters']);
  }

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _name,
      _founder,
      _gstin,
      _address,
      _website,
      _latitude,
      _longitude,
      _radius,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _numberText(Object? value) => value == null ? '' : '$value';

  static String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Map<String, Object?> _body() {
    final local = _kind == 'LOCAL_STORE';
    return {
      if (widget.withCredentials) 'email': _email.text.trim(),
      if (widget.withCredentials) 'password': _password.text,
      'name': _name.text.trim(),
      'founderName': _founder.text.trim(),
      'kind': _kind,
      'categoryId': _categoryId,
      'gstin': _gstin.text.trim().toUpperCase(),
      'registeredAddress': _optional(_address),
      'websiteUrl': _optional(_website),
      'latitude': local ? double.tryParse(_latitude.text.trim()) : null,
      'longitude': local ? double.tryParse(_longitude.text.trim()) : null,
      'radiusMeters': local ? int.tryParse(_radius.text.trim()) : null,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_body());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? Function(String?) _minLength(int min) =>
      (value) => (value ?? '').trim().length < min ? 'Enter at least $min characters' : null;

  Widget _text(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = _kind == 'LOCAL_STORE';
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.withCredentials) ...[
            _text(
              _email,
              'Work email',
              keyboard: TextInputType.emailAddress,
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
            ),
            _text(
              _password,
              'Password (at least 10 characters)',
              obscure: true,
              validator: (v) => (v ?? '').length < 10 ? 'Use at least 10 characters' : null,
            ),
          ],
          _text(_name, 'Brand name', validator: _minLength(2)),
          _text(_founder, 'Founder name', validator: _minLength(2)),
          Text('Business type', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ONLINE', label: Text('Online')),
              ButtonSegment(value: 'LOCAL_STORE', label: Text('Local store')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in widget.categories)
                DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
            validator: (v) => v == null ? 'Choose a category' : null,
          ),
          const SizedBox(height: 12),
          _text(
            _gstin,
            'GSTIN (15 characters)',
            validator: (v) => (v ?? '').trim().length == 15 ? null : 'Enter a 15-character GSTIN',
          ),
          _text(_address, 'Registered address (optional)'),
          _text(_website, 'Website (optional)', keyboard: TextInputType.url),
          if (local) ...[
            Row(
              children: [
                Expanded(
                  child: _text(
                    _latitude,
                    'Latitude',
                    keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _text(
                    _longitude,
                    'Longitude',
                    keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
                  ),
                ),
              ],
            ),
            _text(
              _radius,
              'Shopper radius in metres (50 to 5000)',
              keyboard: TextInputType.number,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return n == null || n < 50 || n > 5000 ? 'Enter a whole number from 50 to 5000' : null;
              },
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
