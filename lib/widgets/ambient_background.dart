import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Different texture types for surfaces
enum TextureType {
  none,
  paper,
  linen,
  parchment,
  smooth,
}

/// Ambient background with subtle gradients and optional texture
class AmbientBackground extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final bool showTexture;
  final TextureType textureType;
  final bool showGradient;
  final List<Color>? gradientColors;

  const AmbientBackground({
    super.key,
    required this.child,
    required this.baseColor,
    this.showTexture = true,
    this.textureType = TextureType.paper,
    this.showGradient = true,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base color
        Container(color: baseColor),

        // Gentle gradient overlay
        if (showGradient)
          Positioned.fill(
            child: CustomPaint(
              painter: _GradientPainter(
                colors: gradientColors ?? _getDefaultGradientColors(context),
              ),
            ),
          ),

        // Texture overlay
        if (showTexture && textureType != TextureType.none)
          Positioned.fill(
            child: CustomPaint(
              painter: _TexturePainter(
                textureType: textureType,
                baseColor: baseColor,
              ),
            ),
          ),

        // Content
        child,
      ],
    );
  }

  List<Color> _getDefaultGradientColors(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = Theme.of(context).colorScheme.primary;

    if (brightness == Brightness.light) {
      return [
        baseColor,
        baseColor.withValues(alpha: 0.7),
        primary.withValues(alpha: 0.02),
        baseColor.withValues(alpha: 0.9),
      ];
    } else {
      return [
        baseColor,
        baseColor.withValues(alpha: 0.8),
        primary.withValues(alpha: 0.03),
        baseColor.withValues(alpha: 0.95),
      ];
    }
  }
}

/// Gentle gradient painter for ambient backgrounds
class _GradientPainter extends CustomPainter {
  final List<Color> colors;

  _GradientPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a subtle radial gradient from top-left
    final gradient = ui.Gradient.radial(
      Offset(size.width * 0.3, size.height * 0.2),
      size.longestSide * 0.8,
      colors,
      [0.0, 0.3, 0.7, 1.0],
      TileMode.clamp,
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) {
    return colors != oldDelegate.colors;
  }
}

/// Texture painter for paper/linen/parchment effects
class _TexturePainter extends CustomPainter {
  final TextureType textureType;
  final Color baseColor;

  _TexturePainter({
    required this.textureType,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (textureType) {
      case TextureType.paper:
        _paintPaperTexture(canvas, size);
        break;
      case TextureType.linen:
        _paintLinenTexture(canvas, size);
        break;
      case TextureType.parchment:
        _paintParchmentTexture(canvas, size);
        break;
      case TextureType.smooth:
        _paintSmoothTexture(canvas, size);
        break;
      case TextureType.none:
        break;
    }
  }

  void _paintPaperTexture(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed for consistency
    final paint = Paint()..style = PaintingStyle.fill;

    // Create subtle paper grain with tiny random dots
    for (int i = 0; i < (size.width * size.height / 100).toInt(); i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.015; // Very subtle

      paint.color = Colors.black.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 0.5 + 0.3,
        paint,
      );
    }
  }

  void _paintLinenTexture(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black.withValues(alpha: 0.01);

    // Create subtle crosshatch pattern for linen
    final spacing = 8.0;

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  void _paintParchmentTexture(Canvas canvas, Size size) {
    final random = math.Random(24); // Fixed seed for consistency
    final paint = Paint()..style = PaintingStyle.fill;

    // Create organic parchment-like texture with slightly larger variations
    for (int i = 0; i < (size.width * size.height / 80).toInt(); i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.02; // Slightly more visible
      final isLight = random.nextBool();

      paint.color = isLight
          ? Colors.white.withValues(alpha: opacity)
          : Colors.black.withValues(alpha: opacity);

      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 1.0 + 0.5,
        paint,
      );
    }
  }

  void _paintSmoothTexture(Canvas canvas, Size size) {
    // Very minimal texture - just a few subtle variations
    final random = math.Random(100);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < (size.width * size.height / 200).toInt(); i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.008; // Extremely subtle

      paint.color = Colors.black.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(x, y),
        0.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TexturePainter oldDelegate) {
    return textureType != oldDelegate.textureType ||
        baseColor != oldDelegate.baseColor;
  }
}

/// Breathing gradient widget that gently pulses
class BreathingGradient extends StatefulWidget {
  final Widget child;
  final Color primaryColor;
  final Duration duration;

  const BreathingGradient({
    super.key,
    required this.child,
    required this.primaryColor,
    this.duration = const Duration(milliseconds: 3000),
  });

  @override
  State<BreathingGradient> createState() => _BreathingGradientState();
}

class _BreathingGradientState extends State<BreathingGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5 - (_animation.value * 0.2),
              colors: [
                widget.primaryColor.withValues(alpha: 0.05 + (_animation.value * 0.03)),
                Colors.transparent,
              ],
              stops: [0.0, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
