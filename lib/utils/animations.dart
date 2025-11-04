import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom easing curves for organic, natural motion
/// These curves make animations feel more intentional and serene
class FlowriteCurves {
  FlowriteCurves._();

  /// Gentle ease out with exponential decay - perfect for fading in elements
  /// Use for: Content appearing, dialogs showing, subtle reveals
  static const Curve gentleReveal = Curves.easeOutExpo;

  /// Smooth ease in-out with quartic motion - balanced, natural movement
  /// Use for: Page transitions, card movements, general animations
  static const Curve organicMotion = Curves.easeInOutQuart;

  /// Very smooth ease out with quintic curve - luxurious, slow ending
  /// Use for: Important transitions, spotlight moments, hero animations
  static const Curve luxuriousEase = Curves.easeOutQuint;

  /// Gentle ease in - subtle acceleration
  /// Use for: Elements disappearing, closing dialogs
  static const Curve softFarewell = Curves.easeInCubic;

  /// Breathing curve - gentle sine wave for pulsing effects
  /// Use for: Pulsing FAB, breathing animations, ambient effects
  static final Curve breathing = _BreathingCurve();

  /// Settling curve - like a leaf landing gently
  /// Use for: Elements settling into place, cards dropping
  static const Curve settling = Curves.easeOutCubic;
}

/// Custom breathing curve for pulsing animations
/// Creates a gentle sine wave effect
class _BreathingCurve extends Curve {
  @override
  double transformInternal(double t) {
    // Sine wave: 0 -> 1 -> 0
    // More gentle than linear oscillation
    return (1 + math.sin((t * 2 * math.pi) - (math.pi / 2))) / 2;
  }
}

/// Standard animation durations for consistent timing
class FlowriteDurations {
  FlowriteDurations._();

  /// Micro-interactions (100-150ms)
  static const Duration micro = Duration(milliseconds: 120);

  /// Quick interactions (150-200ms)
  static const Duration quick = Duration(milliseconds: 180);

  /// Standard interactions (250-350ms)
  static const Duration standard = Duration(milliseconds: 300);

  /// Emphasized interactions (400-500ms)
  static const Duration emphasized = Duration(milliseconds: 450);

  /// Luxurious, important transitions (500-700ms)
  static const Duration luxurious = Duration(milliseconds: 600);

  /// Breathing/pulsing cycle (2-3 seconds for full cycle)
  static const Duration breathingCycle = Duration(milliseconds: 2500);
}

/// Reusable animation widgets for common patterns
class FlowriteAnimations {
  FlowriteAnimations._();

  /// Gentle fade-in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutExpo,
    Duration delay = Duration.zero,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration + delay,
      curve: curve,
      builder: (context, value, child) {
        // Apply delay
        final adjustedValue = delay == Duration.zero
            ? value
            : (value * (duration + delay).inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0);

        return Opacity(
          opacity: adjustedValue,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Gentle scale and fade-in animation (for dialogs, pop-ups)
  static Widget scaleIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutBack,
    double initialScale = 0.9,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final scale = initialScale + (1.0 - initialScale) * value;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Gentle slide-in from direction
  static Widget slideIn({
    required Widget child,
    required Offset begin,
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOutQuart,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: begin, end: Offset.zero),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Pulsing/breathing animation
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 2500),
    double minScale = 0.95,
    double maxScale = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: FlowriteCurves.breathing,
      onEnd: () {
        // This will trigger rebuild and restart animation
      },
      builder: (context, value, child) {
        final scale = minScale + (maxScale - minScale) * value;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Shimmering effect for selected text
  static Widget shimmer({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    Color? highlightColor,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1.0, end: 2.0),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                highlightColor?.withValues(alpha: 0.3) ??
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: child,
    );
  }
}
