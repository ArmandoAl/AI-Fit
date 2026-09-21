import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Botón de acción principal en forma de píldora (pill-shaped) Dark Glam.
///
/// Diseñado para acciones primarias (ej. "DRESS ME", "TRY-ON", "CONTINUAR"):
/// - Gradiente horizontal vibrante: Cyber Pink (#FF1B8D) a Electric Purple (#9B2BEE).
/// - Glow difuso magenta (#FF1B8D con blur 20px).
/// - Tipografía en mayúsculas negrita con letter spacing amplio.
/// - Soporte para iconos de acento (ej. Icons.bolt), estado de carga y deshabilitado.
class GradientPillButton extends StatelessWidget {
  const GradientPillButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 54.0,
    this.width,
    this.gradient,
    this.showGlow = true,
    this.padding,
    this.borderRadius = 999.0,
  });

  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double height;
  final double? width;
  final Gradient? gradient;
  final bool showGlow;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = _isEnabled
        ? (gradient ?? AppColors.primaryButtonGradient)
        : LinearGradient(
            colors: [
              AppColors.surfaceContainerHighest,
              AppColors.surfaceContainerHigh,
            ],
          );

    final effectiveShadows = (_isEnabled && showGlow)
        ? AppColors.primaryButtonGlow
        : null;

    final childContent = Row(
      mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          IconTheme(
            data: const IconThemeData(
              color: Colors.white,
              size: 20,
            ),
            child: icon!,
          ),
          const SizedBox(width: 10),
        ],
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: effectiveGradient,
        boxShadow: effectiveShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: AppColors.neonMint.withValues(alpha: 0.1),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 28),
            child: childContent,
          ),
        ),
      ),
    );
  }
}
