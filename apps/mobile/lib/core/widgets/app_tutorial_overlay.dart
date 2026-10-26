import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings_es.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Tutorial de la app en un único modal con micro-animaciones por capacidad,
/// en vez de un carrusel de texto. Heurística: reconocimiento antes que recuerdo
/// (se puede reabrir desde Perfil) — inspirado en el patrón de onboarding de
/// Diana-Galeria (tarjetas con animación en loop + un solo CTA para empezar).
class AppTutorialOverlay {
  AppTutorialOverlay._();

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutorial',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) => const _TutorialOverlayBody(),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

enum _VisualKind { risingPhoto, slidingGarment, pulseSpark }

class _TutorialCapability {
  final IconData icon;
  final String title;
  final String description;
  final _VisualKind visual;

  const _TutorialCapability({
    required this.icon,
    required this.title,
    required this.description,
    required this.visual,
  });
}

class _TutorialOverlayBody extends StatefulWidget {
  const _TutorialOverlayBody();

  @override
  State<_TutorialOverlayBody> createState() => _TutorialOverlayBodyState();
}

class _TutorialOverlayBodyState extends State<_TutorialOverlayBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  static const _capabilities = [
    _TutorialCapability(
      icon: Icons.camera_alt_outlined,
      title: 'Tu identidad',
      description:
          'Sube fotos claras de cara y cuerpo: el try-on conserva tu piel, tu silueta y tu presencia.',
      visual: _VisualKind.risingPhoto,
    ),
    _TutorialCapability(
      icon: Icons.checkroom_outlined,
      title: AppStringsEs.buildWardrobe,
      description: AppStringsEs.buildWardrobeDesc,
      visual: _VisualKind.slidingGarment,
    ),
    _TutorialCapability(
      icon: Icons.auto_awesome_outlined,
      title: AppStringsEs.getRecommendations,
      description: AppStringsEs.getRecommendationsDesc,
      visual: _VisualKind.pulseSpark,
    ),
  ];

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            boxShadow: AppTheme.ambientCardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'GUÍA RÁPIDA'.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.secondary,
                    tooltip: 'Cerrar',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                'Así funciona AI-Fit',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              for (final capability in _capabilities) ...[
                _CapabilityRow(capability: capability, loop: _loop),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Puedes volver a ver esta guía cuando quieras desde tu Perfil.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ENTENDIDO, EMPEZAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final _TutorialCapability capability;
  final AnimationController loop;

  const _CapabilityRow({required this.capability, required this.loop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AnimatedVisual(icon: capability.icon, kind: capability.visual, loop: loop),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                capability.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                capability.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circulo de 64x64 con una micro-animación en loop que representa la acción
/// de la capacidad (una foto que "entra" al perfil, una prenda que se agrega
/// al armario, una chispa que enciende una recomendación), en vez de un
/// ícono estático — mismo patrón que las tarjetas de gesto de Diana-Galeria.
class _AnimatedVisual extends StatelessWidget {
  final IconData icon;
  final _VisualKind kind;
  final AnimationController loop;

  static const double _size = 64;

  const _AnimatedVisual({required this.icon, required this.kind, required this.loop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainerHigh,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          style: BorderStyle.solid,
        ),
      ),
      child: ClipOval(
        child: AnimatedBuilder(
          animation: loop,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 26, color: AppColors.primary.withValues(alpha: 0.3)),
              _buildMovingGlyph(loop.value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovingGlyph(double t) {
    switch (kind) {
      case _VisualKind.risingPhoto:
        // Una miniatura "foto" sube desde abajo hacia el centro y se disuelve, en loop.
        final local = t < 0.5 ? t / 0.5 : (t - 0.5) / 0.5;
        final dy = t < 0.5 ? 16 * (1 - local) : -16 * local;
        final opacity = t < 0.5 ? local : 1 - local;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      case _VisualKind.slidingGarment:
        // Una prenda se desliza de izquierda a derecha "entrando" al armario, en loop.
        final local = t < 0.5 ? t / 0.5 : (t - 0.5) / 0.5;
        final dx = t < 0.5 ? -18 * (1 - local) : 18 * local;
        final opacity = t < 0.5 ? local : 1 - local;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: const Icon(Icons.checkroom, size: 18, color: AppColors.gold),
          ),
        );
      case _VisualKind.pulseSpark:
        // Una chispa "enciende" el ícono con un pulso de escala y brillo, en loop.
        final scale = 1.0 + 0.22 * math.sin(2 * math.pi * t);
        final opacity = 0.55 + 0.45 * math.sin(2 * math.pi * t).abs();
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: const Icon(Icons.auto_awesome, size: 20, color: AppColors.gold),
          ),
        );
    }
  }
}
