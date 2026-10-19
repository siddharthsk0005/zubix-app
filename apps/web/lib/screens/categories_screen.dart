import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/api_client.dart';

/// Lists categories in display order. Supports add, rename, activate/deactivate and reorder.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.api, required this.token});

  final AdminApi api;
  final String token;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _rows = [];
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
      _rows = await widget.api.listCategories(widget.token);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _move(int index, int delta) {
    final ids = _rows.map((r) => r['id'] as String).toList();
    final target = index + delta;
    if (target < 0 || target >= ids.length) return Future.value();
    final id = ids.removeAt(index);
    ids.insert(target, id);
    return _run(() => widget.api.reorderCategories(widget.token, ids));
  }

  Future<void> _nameDialog({Map<String, dynamic>? existing}) async {
    final controller = TextEditingController(text: existing?['name'] as String? ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add category' : 'Rename category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    await _run(() => existing == null
        ? widget.api.createCategory(widget.token, name)
        : widget.api.updateCategory(widget.token, existing['id'] as String, name: name));
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
              Expanded(child: Text('Categories', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: () => _nameDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
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
    if (_rows.isEmpty) return const Center(child: Text('No categories yet. Add one to get started.'));

    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final row = _rows[i];
        final active = row['isActive'] as bool;
        return ListTile(
          leading: Text('${i + 1}'),
          title: Text(row['name'] as String),
          subtitle: Text(active ? 'Active' : 'Hidden from users'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move up',
                onPressed: i == 0 ? null : () => _move(i, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: i == _rows.length - 1 ? null : () => _move(i, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Rename',
                onPressed: () => _nameDialog(existing: row),
                icon: const Icon(Icons.edit_outlined),
              ),
              Switch(
                value: active,
                onChanged: (value) => _run(
                  () => widget.api.updateCategory(widget.token, row['id'] as String, isActive: value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
