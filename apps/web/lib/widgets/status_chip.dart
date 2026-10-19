import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Monochrome status pill. Active states (approved, live) are filled black.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final strong = status == 'APPROVED' || status == 'LIVE';
    final label = status[0] + status.substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? AppColors.black : AppColors.white,
        border: Border.all(color: strong ? AppColors.black : AppColors.grey500),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: strong ? AppColors.white : AppColors.grey700,
        ),
      ),
    );
  }
}
