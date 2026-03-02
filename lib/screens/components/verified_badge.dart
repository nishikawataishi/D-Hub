import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool showTooltip;

  const VerifiedBadge({super.key, this.size = 18, this.showTooltip = true});

  @override
  Widget build(BuildContext context) {
    final badge = Icon(
      Icons.verified,
      size: size,
      color: const Color(0xFFFFD700), // ゴールド系
    );

    if (!showTooltip) return badge;

    return Tooltip(
      message: '運営によって実在が確認された団体です',
      triggerMode: TooltipTriggerMode.tap,
      child: badge,
    );
  }
}
