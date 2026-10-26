import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/app_strings_es.dart';
import '../../core/utils/keyboard_utils.dart';
import 'luxury_bottom_nav_bar.dart';

/// Shell principal — navigationShell único; nav se oculta con teclado.
class MainLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({super.key, required this.navigationShell});

  static const _destinations = [
    LuxuryNavDestination(
      icon: Icons.checkroom_outlined,
      selectedIcon: Icons.checkroom_rounded,
      label: AppStringsEs.navWardrobe,
    ),
    LuxuryNavDestination(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      label: AppStringsEs.navStylist,
    ),
    LuxuryNavDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: AppStringsEs.navProfile,
    ),
  ];

  void _onTabSelected(BuildContext context, int index) {
    hideKeyboard();

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      extendBody: false,
      body: navigationShell,
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: keyboardOpen
            ? const SizedBox.shrink(key: ValueKey('nav_hidden'))
            : LuxuryBottomNavBar(
                key: const ValueKey('nav_visible'),
                selectedIndex: navigationShell.currentIndex,
                onSelected: (index) => _onTabSelected(context, index),
                destinations: _destinations,
              ),
      ),
    );
  }
}
