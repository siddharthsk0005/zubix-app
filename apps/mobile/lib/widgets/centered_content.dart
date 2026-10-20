import 'package:flutter/material.dart';

/// Caps body width so lists stay readable on tablets, iPads and web.
/// Phones are narrower than [maxWidth], so they are unaffected.
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
