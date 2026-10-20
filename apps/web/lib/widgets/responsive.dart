import 'package:flutter/material.dart';

/// Screens at or above this width get a side rail. Narrower screens get a bottom bar.
const double kWideLayoutBreakpoint = 800;

/// Two fields side by side, stacked when the space is narrow.
class TwoUp extends StatelessWidget {
  const TwoUp({
    super.key,
    required this.first,
    required this.second,
    this.stackBelow = 480,
  });

  final Widget first;
  final Widget second;
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

/// Width for a dialog's content that still fits small phone screens.
double dialogContentWidth(BuildContext context, {double max = 380}) {
  final screen = MediaQuery.sizeOf(context).width;
  return (screen - 140).clamp(200.0, max).toDouble();
}
