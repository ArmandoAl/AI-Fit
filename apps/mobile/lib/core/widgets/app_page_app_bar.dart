import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Editorial app bar — parchment canvas, gold hairline, serif title.
class AppPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const AppPageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle != null ? 72 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onSurface,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.border.withValues(alpha: 0),
                AppColors.gold.withValues(alpha: 0.55),
                AppColors.border.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.tertiary,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: theme.textTheme.headlineSmall,
            ),
      centerTitle: false,
      actions: actions,
    );
  }
}

/// AppBar para pantallas secundarias (stack con back).
class AppSubpageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const AppSubpageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle != null ? 72 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppPageAppBar(
      title: title,
      subtitle: subtitle,
      actions: actions,
    );
  }
}
