/// Avatar — circular initials avatar, matching the reference prototype's
/// Avatar component (ui.tsx). Also provides AvatarStack for overlapping
/// avatar groups (split member display in expense feed).
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SplitsaAvatar extends StatelessWidget {
  const SplitsaAvatar({
    super.key,
    required this.name,
    this.tone = AppColors.textSecondary,
    this.size = 44.0,
    this.ring = false,
    this.ringColor,
  });

  final String name;
  final Color tone;
  final double size;

  /// Whether to render the double-ring focus indicator (active selection).
  final bool ring;
  final Color? ringColor;

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone, Color.lerp(tone, Colors.black, 0.27)!],
        ),
        boxShadow: ring
            ? [
                BoxShadow(color: AppColors.background, spreadRadius: 2, blurRadius: 0),
                BoxShadow(
                  color: (ringColor ?? tone).withOpacity(0.4),
                  spreadRadius: 3.5,
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: AppColors.background,
          height: 1,
        ),
      ),
    );

    return child;
  }
}

/// Overlapping avatar stack — used in expense feed rows to show split members.
/// Renders up to [maxVisible] avatars; if more, shows a "+N" overflow badge.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    required this.tones,
    this.size = 22.0,
    this.maxVisible = 4,
  });

  final List<String> names;
  final List<Color> tones;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final showCount = names.length.clamp(0, maxVisible);
    final overflow  = names.length - showCount;
    final totalWidth = size + (showCount - 1) * (size * 0.55) + (overflow > 0 ? size * 0.55 : 0);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < showCount; i++)
            Positioned(
              left: i * size * 0.55,
              child: SplitsaAvatar(
                name: names[i],
                tone: i < tones.length ? tones[i] : AppColors.textSecondary,
                size: size,
                ring: true,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: showCount * size * 0.55,
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
