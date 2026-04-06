import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:transaction_app/services/hardware_capabilities.dart';

/// ============================================================================
/// HARDWARE-AWARE THEME CONFIGURATION
/// ============================================================================
/// Provides theme configurations adapted to device hardware capabilities.
/// Low-end devices get simplified effects, high-end devices get full effects.
/// ============================================================================

class HardwareAwareTheme {
  final HardwareCapabilities _hardware = HardwareCapabilities();

  /// Get shadow configuration based on hardware
  BoxShadow get shadow {
    if (_hardware.shouldDisableShadows) {
      // No shadows for low-end devices
      return const BoxShadow(
        color: Colors.transparent,
        blurRadius: 0,
        spreadRadius: 0,
      );
    }

    if (_hardware.isHighEndDevice) {
      // Full shadows for high-end
      return BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 12,
        spreadRadius: 2,
      );
    }

    // Simplified shadows for mid-range
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      spreadRadius: 1,
    );
  }

  /// Get card decoration based on hardware
  BoxDecoration get cardDecoration {
    if (_hardware.shouldDisableShadows) {
      // Simple border for low-end
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      );
    }

    // Full decoration with shadows
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [shadow],
    );
  }

  /// Get blur effect (only for high-end devices)
  Widget withBlurEffect({
    required Widget child,
    double blur = 10.0,
  }) {
    if (_hardware.shouldDisableBlurs) {
      // No blur for low-end - return child as-is
      return child;
    }

    // Apply blur for mid-range and high-end
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }

  /// Get animation duration based on hardware
  Duration get animationDuration {
    final multiplier = _hardware.animationDurationMultiplier;
    if (multiplier == 0) return Duration.zero;
    return Duration(milliseconds: (300 * multiplier).round());
  }

  /// Get short animation duration
  Duration get shortAnimationDuration {
    final multiplier = _hardware.animationDurationMultiplier;
    if (multiplier == 0) return Duration.zero;
    return Duration(milliseconds: (150 * multiplier).round());
  }

  /// Get long animation duration
  Duration get longAnimationDuration {
    final multiplier = _hardware.animationDurationMultiplier;
    if (multiplier == 0) return Duration.zero;
    return Duration(milliseconds: (500 * multiplier).round());
  }

  /// Get curve based on hardware
  Curve get curve {
    if (_hardware.isLowEndDevice) {
      return Curves.linear; // Simplest curve
    }
    return Curves.easeOutCubic; // Smoother curve
  }

  /// Get page transition builder based on hardware
  Route<T> buildPageTransition<T>({
    required Widget page,
    required BuildContext context,
  }) {
    if (_hardware.shouldDisableAnimations) {
      // No animation for low-end
      return PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    // Fade transition for mid-range
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: animationDuration,
      reverseTransitionDuration: animationDuration,
    );
  }

  /// Get list view scroll physics based on hardware
  ScrollPhysics get scrollPhysics {
    if (_hardware.isLowEndDevice) {
      return const ScrollPhysics(
        parent: ClampingScrollPhysics(),
      );
    }
    return const BouncingScrollPhysics();
  }

  /// Get image cache size based on hardware
  int get imageCacheSize {
    return (100 * _hardware.cacheSizeMultiplier).round();
  }

  /// Get whether to use cached images
  bool get useCachedImages => true;

  /// Get whether to preload images
  bool get shouldPreloadImages => _hardware.isHighEndDevice;
}

/// ============================================================================
/// HARDWARE-AWARE CONTAINER
/// ============================================================================
/// A container widget that adapts its decoration based on hardware
/// ============================================================================

class HardwareAwareContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxDecoration? decoration;
  final Color? color;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  const HardwareAwareContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.decoration,
    this.color,
    this.borderRadius,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = HardwareAwareTheme();

    // Build decoration based on hardware
    BoxDecoration? finalDecoration;

    if (decoration != null) {
      finalDecoration = decoration;
    } else if (color != null || borderRadius != null || border != null) {
      finalDecoration = BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: border,
        // Only add shadows if hardware supports it
        boxShadow:
            _hardware.shouldDisableShadows ? null : (shadows ?? [theme.shadow]),
      );
    } else if (!_hardware.shouldDisableShadows) {
      // Default decoration with shadows for non-low-end devices
      finalDecoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [theme.shadow],
      );
    }

    return Container(
      margin: margin,
      padding: padding,
      decoration: finalDecoration,
      child: child,
    );
  }

  HardwareCapabilities get _hardware => HardwareCapabilities();
}

/// ============================================================================
/// HARDWARE-AWARE CARD
/// ============================================================================
/// A card widget that adapts its elevation and effects based on hardware
/// ============================================================================

class HardwareAwareCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? borderRadius;
  final VoidCallback? onTap;

  const HardwareAwareCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = HardwareAwareTheme();

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: theme.cardDecoration.copyWith(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// ============================================================================
/// HARDWARE-AWARE LIST TILE
/// ============================================================================
/// A list tile that adap its animation and effects based on hardware
/// ============================================================================

class HardwareAwareListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  const HardwareAwareListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final hardware = HardwareCapabilities();
    final theme = HardwareAwareTheme();

    final tile = ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      contentPadding: contentPadding,
      onTap: onTap,
    );

    if (hardware.shouldDisableAnimations) {
      return tile;
    }

    // Add subtle animation for non-low-end devices
    return AnimatedOpacity(
      opacity: 1.0,
      duration: theme.shortAnimationDuration,
      child: tile,
    );
  }
}
