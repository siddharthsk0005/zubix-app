import 'package:flutter/material.dart';

import '../api/api_client.dart';

typedef LoadRows = Future<List<Map<String, dynamic>>> Function(String? status);
typedef ReviewRow = Future<void> Function(String id, {required bool approve, String? note});

/// Pending, approved and rejected registrations, with approve and reject actions.
class ReviewQueue extends StatefulWidget {
  const ReviewQueue({
    super.key,
    required this.title,
    required this.load,
    required this.review,
    required this.labelOf,
    required this.detailOf,
    this.statuses = defaultStatuses,
    this.pendingStatus = 'PENDING',
  });

  static const defaultStatuses = [
    (value: 'PENDING', label: 'Pending'),
    (value: 'APPROVED', label: 'Approved'),
    (value: 'REJECTED', label: 'Rejected'),
  ];

  final String title;
  final LoadRows load;
  final ReviewRow review;
  final String Function(Map<String, dynamic> row) labelOf;
  final String Function(Map<String, dynamic> row) detailOf;
  final List<({String value, String label})> statuses;

  /// Rows in this status show approve and reject actions.
  final String pendingStatus;

  @override
  State<ReviewQueue> createState() => _ReviewQueueState();
}

class _ReviewQueueState extends State<ReviewQueue> {
  late String _status;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.pendingStatus;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await widget.load(_status);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> row, {required bool approve}) async {
    final note = await showDialog<String?>(
      context: context,
      builder: (_) => _NoteDialog(
        title: approve ? 'Approve ${widget.labelOf(row)}?' : 'Reject ${widget.labelOf(row)}?',
        noteRequired: !approve,
        actionLabel: approve ? 'Approve' : 'Reject',
      ),
    );
    if (note == null) return; // Cancelled.

    try {
      await widget.review(row['id'] as String, approve: approve, note: note.isEmpty ? null : note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Approved' : 'Rejected')),
      );
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              for (final s in widget.statuses)
                ButtonSegment(value: s.value, label: Text(s.label)),
            ],
            selected: {_status},
            onSelectionChanged: (s) {
              setState(() => _status = s.first);
              _refresh();
            },
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
    if (_rows.isEmpty) return const Center(child: Text('Nothing here yet.'));

    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final row = _rows[i];
        final note = row['reviewNote'] as String?;
        return ListTile(
          title: Text(widget.labelOf(row)),
          subtitle: Text(
            [widget.detailOf(row), if (note != null && note.isNotEmpty) 'Note: $note']
                .where((s) => s.isNotEmpty)
                .join('\n'),
          ),
          isThreeLine: note != null && note.isNotEmpty,
          trailing: _status == widget.pendingStatus
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: () => _decide(row, approve: false), child: const Text('Reject')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => _decide(row, approve: true), child: const Text('Approve')),
                  ],
                )
              : null,
        );
      },
    );
  }
}

/// Returns the entered note, or null if cancelled. Rejections need a non-empty note.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.noteRequired, required this.actionLabel});

  final String title;
  final bool noteRequired;
  final String actionLabel;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _controller.text.trim();
    if (widget.noteRequired && note.isEmpty) {
      setState(() => _error = 'A note is required when rejecting');
      return;
    }
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _controller,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: widget.noteRequired ? 'Reason (required)' : 'Note (optional)',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
