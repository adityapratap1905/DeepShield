import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated background supporting Horizon Wave (Light) and Orbital Minimal (Dark).
class DSAuroraBackground extends StatefulWidget {
  final Widget child;
  final bool animate;
  final bool subtle;

  const DSAuroraBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.subtle = false,
  });

  @override
  State<DSAuroraBackground> createState() => _DSAuroraBackgroundState();
}

class _DSAuroraBackgroundState extends State<DSAuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return ColoredBox(
        color: AppColors.backgroundLight,
        child: widget.child,
      );
    }

    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Stack(
        children: [
          if (widget.animate)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                size: MediaQuery.sizeOf(context),
                painter: _AmbientPainter(
                  progress: _ctrl.value,
                  subtle: widget.subtle,
                  isDark: isDark,
                ),
              ),
            )
          else
            CustomPaint(
              size: MediaQuery.sizeOf(context),
              painter: _AmbientPainter(
                progress: 0.3,
                subtle: widget.subtle,
                isDark: isDark,
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final double progress;
  final bool subtle;
  final bool isDark;

  _AmbientPainter({
    required this.progress,
    required this.subtle,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double t = progress * 2 * math.pi;
    final double opacity =
        subtle ? (isDark ? 0.15 : 0.4) : (isDark ? 0.25 : 0.6);

    // Orbital Minimal (Dark) or Horizon Wave (Light)
    final color1 = isDark ? const Color(0xFF00E5FF) : const Color(0xFF00B8D4);
    final color2 = isDark ? const Color(0xFF2962FF) : const Color(0xFF1565C0);
    final color3 = isDark ? const Color(0xFF00B8D4) : const Color(0xFF4DD0E1);

    // Top Right Orb
    final orb1Center = Offset(
      w * 0.8 + math.sin(t) * w * 0.1,
      h * 0.15 + math.cos(t * 0.8) * h * 0.1,
    );
    _drawOrb(canvas, orb1Center, w * 0.45, color1, opacity);

    // Center Left Orb
    final orb2Center = Offset(
      w * 0.2 + math.cos(t * 0.7) * w * 0.1,
      h * 0.5 + math.sin(t * 0.9) * h * 0.1,
    );
    _drawOrb(canvas, orb2Center, w * 0.5, color2, opacity * 0.8);

    // Bottom Right Orb
    final orb3Center = Offset(
      w * 0.7 + math.sin(t * 0.5) * w * 0.1,
      h * 0.85 + math.cos(t * 0.6) * h * 0.1,
    );
    _drawOrb(canvas, orb3Center, w * 0.4, color3, opacity * 0.7);
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color,
      double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.3),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}
