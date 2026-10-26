import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Lookbook section kicker + serif title.
class AtelierSectionHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AtelierSectionHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
