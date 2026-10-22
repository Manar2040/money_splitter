import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final int colorSeedIndex;
  final double radius;
  final bool showBorder;

  const AvatarWidget({
    super.key,
    required this.name,
    this.imageUrl,
    this.colorSeedIndex = 0,
    this.radius = 20,
    this.showBorder = false,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _seedColor {
    final colors = AppConstants.avatarColors;
    return colors[colorSeedIndex % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _seedColor.withOpacity(isDark ? 0.25 : 0.15),
        border: showBorder
            ? Border.all(
                color: _seedColor,
                width: 2,
              )
            : null,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: isDark ? _seedColor.withOpacity(0.9) : _seedColor,
            fontSize: radius * 0.85,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
