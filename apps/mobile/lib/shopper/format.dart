import 'package:flutter/material.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "5 Jun, 2:30 PM" in the phone's time zone.
String formatWhen(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final time = TimeOfDay.fromDateTime(local).format(context);
  return '${local.day} ${_months[local.month - 1]}, $time';
}

/// "AVAILABLE" becomes "Available".
String prettyStatus(String status) {
  if (status.isEmpty) return status;
  return '${status[0]}${status.substring(1).toLowerCase()}';
}
