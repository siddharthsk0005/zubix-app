import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/brand_api.dart';
import '../util/format.dart';
import '../widgets/status_chip.dart';

/// Brand's coupon sessions. Requests are only allowed once the brand is approved.
class BrandSessionsScreen extends StatefulWidget {
  const BrandSessionsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.canRequest,
  });

  final BrandApi api;
  final String token;
  final bool canRequest;

  @override
  State<BrandSessionsScreen> createState() => _BrandSessionsScreenState();
}

class _BrandSessionsScreenState extends State<BrandSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _sessions = await widget.api.sessions(widget.token);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _request() async {
    final body = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _RequestSessionDialog(),
    );
    if (body == null) return;
    try {
      await widget.api.requestSession(widget.token, body);
      _snack('Session requested');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _cancel(Map<String, dynamic> session) async {
    try {
      await widget.api.cancelSession(widget.token, session['id'] as String);
      _snack('Session cancelled');
      await _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Sessions', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: widget.canRequest ? _request : null,
                icon: const Icon(Icons.add),
                label: const Text('Request session'),
              ),
            ],
          ),
          if (!widget.canRequest)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Session requests open after admin approval.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_sessions.isEmpty) return const Center(child: Text('No sessions yet.'));

    return ListView.separated(
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = _sessions[i];
        final status = s['status'] as String;
        final note = s['reviewNote'] as String?;
        final cancellable = status == 'REQUESTED' || status == 'APPROVED';
        final start = DateTime.parse(s['startsAt'] as String);
        final end = DateTime.parse(s['endsAt'] as String);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          title: Text(s['title'] as String),
          subtitle: Text(
            [
              '${formatDateTime(start)} to ${formatDateTime(end)}',
              '${s['discountPercent']}% off · ${s['couponCount']} coupons',
              if (note != null && note.isNotEmpty) 'Note: $note',
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusChip(status),
              if (cancellable) ...[
                const SizedBox(width: 12),
                TextButton(onPressed: () => _cancel(s), child: const Text('Cancel')),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Collects session details. Returns the request body, or null if cancelled.
class _RequestSessionDialog extends StatefulWidget {
  const _RequestSessionDialog();

  @override
  State<_RequestSessionDialog> createState() => _RequestSessionDialogState();
}

class _RequestSessionDialogState extends State<_RequestSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _tag = TextEditingController();
  final _discount = TextEditingController(text: '20');
  final _coupons = TextEditingController(text: '50');

  DateTime _startsAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _endsAt = DateTime.now().add(const Duration(hours: 4));
  DateTime _couponExpiresAt = DateTime.now().add(const Duration(hours: 4));
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _tag, _discount, _coupons]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Picks a date, then a time, and keeps the result in local time.
  Future<DateTime?> _pickDateTime(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_endsAt.isAfter(_startsAt)) {
      setState(() => _error = 'End time must be after start time');
      return;
    }
    if (_couponExpiresAt.isBefore(_endsAt)) {
      setState(() => _error = 'Coupon expiry must be at or after the end time');
      return;
    }
    Navigator.of(context).pop({
      'title': _title.text.trim(),
      'createdByTag': _tag.text.trim(),
      'discountPercent': int.parse(_discount.text.trim()),
      'couponCount': int.parse(_coupons.text.trim()),
      'startsAt': _startsAt.toUtc().toIso8601String(),
      'endsAt': _endsAt.toUtc().toIso8601String(),
      'couponExpiresAt': _couponExpiresAt.toUtc().toIso8601String(),
    });
  }

  Widget _whenTile(String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(formatDateTime(value)),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: () async {
        final picked = await _pickDateTime(value);
        if (picked != null) setState(() => onChanged(picked));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request a coupon session'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Session title'),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Enter at least 3 characters' : null,
                ),
                TextFormField(
                  controller: _tag,
                  decoration: const InputDecoration(labelText: 'Label (e.g. Lunch)'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Discount %'),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n == null || n < 1 || n > 90 ? '1 to 90' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _coupons,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Coupons'),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n == null || n < 1 ? 'At least 1' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _whenTile('Starts', _startsAt, (v) => _startsAt = v),
                _whenTile('Ends', _endsAt, (v) => _endsAt = v),
                _whenTile('Coupons expire', _couponExpiresAt, (v) => _couponExpiresAt = v),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Send request')),
      ],
    );
  }
}
