import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Badge de compatibilidad "Match Score" con estética gótica neón / alas de murciélago (Monster High Draculaura).
///
/// Muestra el porcentaje de armonía del look (ej. `98% MATCH!`) con tipografía semibold
/// en color menta eléctrico (#00F5D4) y un contorno estilizado con alas de murciélago en magenta neón (#FF2A85).
class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({
    super.key,
    required this.score,
    this.label,
    this.showWings = true,
  });

  final int score;
  final String? label;
  final bool showWings;

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0, 100);
    final statusText = label ??
        (clampedScore >= 90
            ? 'DROP DEAD GORGEOUS'
            : clampedScore >= 75
                ? 'TOTALLY CLUELESS MATCH'
                : 'ECLECTIC MIX');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: showWings ? BatWingsPainter() : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.neonMagenta,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55FF2A85),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x3300F5D4),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.neonMint,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$clampedScore% MATCH!',
                  style: const TextStyle(
                    color: AppColors.neonMint,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.bolt,
                  color: AppColors.neonMagenta,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          statusText.toUpperCase(),
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter que esculpe siluetas estilizadas de alas de murciélago en los laterales
class BatWingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neonMagenta.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;

    // Ala Izquierda
    final leftWing = Path();
    leftWing.moveTo(0, centerY - 2);
    leftWing.cubicTo(
      -14, centerY - 14,
      -22, centerY - 8,
      -30, centerY - 16,
    );
    leftWing.cubicTo(
      -26, centerY - 4,
      -28, centerY + 8,
      -18, centerY + 10,
    );
    leftWing.cubicTo(
      -12, centerY + 14,
      -6, centerY + 8,
      0, centerY + 2,
    );
    canvas.drawPath(leftWing, paint);

    // Ala Derecha
    final rightWing = Path();
    final rightEdge = size.width;
    rightWing.moveTo(rightEdge, centerY - 2);
    rightWing.cubicTo(
      rightEdge + 14, centerY - 14,
      rightEdge + 22, centerY - 8,
      rightEdge + 30, centerY - 16,
    );
    rightWing.cubicTo(
      rightEdge + 26, centerY - 4,
      rightEdge + 28, centerY + 8,
      rightEdge + 18, centerY + 10,
    );
    rightWing.cubicTo(
      rightEdge + 12, centerY + 14,
      rightEdge + 6, centerY + 8,
      rightEdge, centerY + 2,
    );
    canvas.drawPath(rightWing, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
