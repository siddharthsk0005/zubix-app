const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Formats a time in local time, e.g. "05 Jun 2030, 18:00".
String formatDateTime(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)} ${_months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}
