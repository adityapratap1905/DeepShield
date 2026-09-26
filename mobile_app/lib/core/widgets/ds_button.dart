import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// DeepShield primary button variants
enum DSButtonVariant { primary, secondary, ghost, danger }

/// Production-grade button with micro-animations and multiple variants.
class DSButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double height;

  const DSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height = 52,
  });

  @override
  State<DSButton> createState() => _DSButtonState();
}

class _DSButtonState extends State<DSButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.isLoading;

    Widget child = _buildChild(context);

    if (widget.isFullWidth || widget.width != null) {
      child = SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height,
        child: child,
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && !disabled ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: child,
      ),
    );
  }

  Widget _buildChild(BuildContext context) {
    switch (widget.variant) {
      case DSButtonVariant.primary:
        return _primaryButton(context);
      case DSButtonVariant.secondary:
        return _secondaryButton(context);
      case DSButtonVariant.ghost:
        return _ghostButton(context);
      case DSButtonVariant.danger:
        return _dangerButton(context);
    }
  }

  Widget _primaryButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        gradient: widget.onPressed != null && !widget.isLoading
            ? (isDark ? AppColors.primaryGradientDark : AppColors.primaryGradientLight)
            : LinearGradient(colors: [
                isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
              ]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.onPressed != null && !widget.isLoading
            ? [BoxShadow(color: isDark ? AppColors.primaryGlow : AppColors.primaryLight.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white12,
          child: Center(child: _buttonContent(isDark ? const Color(0xFF030509) : Colors.white)),
        ),
      ),
    );
  }

  Widget _secondaryButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final container = isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;
    
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary, width: 1.5),
        color: container.withValues(alpha: 0.3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: isDark ? AppColors.primaryGlow : AppColors.primaryLight.withValues(alpha: 0.1),
          child: Center(child: _buttonContent(primary)),
        ),
      ),
    );
  }

  Widget _ghostButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return SizedBox(
      height: widget.height,
      child: TextButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _buttonContent(color),
      ),
    );
  }

  Widget _dangerButton(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        gradient: AppColors.dangerGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.dangerGlow, blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white12,
          child: Center(child: _buttonContent(Colors.white)),
        ),
      ),
    );
  }

  Widget _buttonContent(Color color) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leadingIcon != null) ...[
          Icon(widget.leadingIcon, color: color, size: 18),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, color: color, size: 18),
        ],
      ],
    );
  }
}
