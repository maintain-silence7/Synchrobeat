import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Primary action button with a vibrant gradient, rounded corners,
/// glowing drop shadow, and loading state.
class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.gradient,
    this.height = 52,
    this.isFullWidth = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool isLoading;
  final Gradient? gradient;
  final double height;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? AppTheme.primaryGradient;
    final isDisabled = onPressed == null || isLoading;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        gradient: isDisabled
            ? LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.35),
                  AppTheme.primaryDark.withValues(alpha: 0.35),
                ],
              )
            : effectiveGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDisabled ? null : onPressed,
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize:
                          isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          icon!,
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}

/// Frosted/Glass secondary button with a subtle border and accent color.
class SecondaryOutlinedButton extends StatelessWidget {
  const SecondaryOutlinedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.accentColor,
    this.height = 50,
    this.isFullWidth = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final Color? accentColor;
  final double height;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.secondary;
    final isDisabled = onPressed == null;

    final child = Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDisabled
              ? AppTheme.surfaceBorder
              : color.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDisabled ? null : onPressed,
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.08),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize:
                    isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: isDisabled ? AppTheme.textSecondary : color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}

/// Circular glowing playback button for Play / Pause.
class PlaybackControlButton extends StatelessWidget {
  const PlaybackControlButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.size = 64,
    this.iconSize = 34,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.45),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: iconSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted circular button for Previous / Next controls.
class SkipControlButton extends StatelessWidget {
  const SkipControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 46,
    this.iconSize = 28,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceHighlight.withValues(alpha: 0.6),
        border: Border.all(
          color: AppTheme.surfaceBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          splashColor: AppTheme.primaryAccent.withValues(alpha: 0.2),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
