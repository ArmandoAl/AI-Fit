import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tarjeta Dark Glam / Y2K Cyber-Goth con borde gradiente y glow sutil.
///
/// Implementa un borde de gradiente Clueless-Goth (#FF2A85 Magenta a #00F5D4 Menta)
/// con curvatura de 18px y fondo ciruela profundo (#1D1626).
class GlowingBorderCard extends StatelessWidget {
  const GlowingBorderCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 18.0,
    this.borderWidth = 1.5,
    this.borderGradient,
    this.backgroundColor,
    this.showGlow = true,
    this.glowShadows,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final double borderWidth;
  final Gradient? borderGradient;
  final Color? backgroundColor;
  final bool showGlow;
  final List<BoxShadow>? glowShadows;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = borderGradient ?? AppColors.cluelessGothBorderGradient;
    final effectiveBackground = backgroundColor ?? AppColors.cardBackground;
    final effectiveShadows = showGlow
        ? (glowShadows ?? AppColors.neonBorderGlow)
        : null;

    final innerRadius = (borderRadius - borderWidth).clamp(0.0, double.infinity);

    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(innerRadius),
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(innerRadius),
          splashColor: AppColors.neonMagenta.withValues(alpha: 0.15),
          highlightColor: AppColors.neonMint.withValues(alpha: 0.08),
          child: cardContent,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: effectiveGradient,
        boxShadow: effectiveShadows,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        clipBehavior: clipBehavior,
        child: cardContent,
      ),
    );
  }
}
