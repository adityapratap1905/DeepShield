import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated gradient background that slowly shifts hue — adds depth to screens.
class DSAnimatedGradient extends StatefulWidget {
  final Widget child;
  final bool animate;

  const DSAnimatedGradient({super.key, required this.child, this.animate = true});

  @override
  State<DSAnimatedGradient> createState() => _DSAnimatedGradientState();
}

class _DSAnimatedGradientState extends State<DSAnimatedGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              Color.lerp(
                const Color(0xFF050508),
                const Color(0xFF0A0520),
                _anim.value,
              )!,
              AppColors.backgroundDark,
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Shield radar pulse animation for splash / scan screens
class DSRadarPulse extends StatefulWidget {
  final double size;
  final Color color;
  final int pulseCount;

  const DSRadarPulse({
    super.key,
    this.size = 200,
    this.color = AppColors.primary,
    this.pulseCount = 3,
  });

  @override
  State<DSRadarPulse> createState() => _DSRadarPulseState();
}

class _DSRadarPulseState extends State<DSRadarPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RadarPainter(
          progress: _ctrl.value,
          color: widget.color,
          pulseCount: widget.pulseCount,
        ),
        child: child,
      ),
      child: SizedBox(width: widget.size, height: widget.size),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int pulseCount;

  _RadarPainter({required this.progress, required this.color, required this.pulseCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < pulseCount; i++) {
      final offset = i / pulseCount;
      final t = (progress + offset) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1 - t) * 0.6;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.progress != progress;
}

/// A shield icon with rotating border for active scan states
class DSShieldLoader extends StatefulWidget {
  final double size;
  const DSShieldLoader({super.key, this.size = 80});

  @override
  State<DSShieldLoader> createState() => _DSShieldLoaderState();
}

class _DSShieldLoaderState extends State<DSShieldLoader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ArcPainter(),
          child: SizedBox(width: widget.size, height: widget.size),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
