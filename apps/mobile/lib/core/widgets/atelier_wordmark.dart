import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Wordmark editorial: serif AIFIT + champagne hairline.
class AtelierWordmark extends StatelessWidget {
  final Color color;
  final double fontSize;
  final bool showRule;
  final String kicker;

  const AtelierWordmark({
    super.key,
    this.color = AppColors.onSurface,
    this.fontSize = 42,
    this.showRule = true,
    this.kicker = 'ATELIER',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AIFit',
          style: GoogleFonts.cormorantGaramond(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.05,
            letterSpacing: 4,
            color: color,
          ),
        ),
        if (showRule) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 18, height: 0.8, color: AppColors.gold),
              const SizedBox(width: 10),
              Text(
                kicker,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4.2,
                  color: color.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 18, height: 0.8, color: AppColors.gold),
            ],
          ),
        ],
      ],
    );
  }
}
