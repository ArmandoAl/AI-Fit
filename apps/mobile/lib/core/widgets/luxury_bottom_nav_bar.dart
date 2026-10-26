import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class LuxuryNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const LuxuryNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Barra inferior premium con indicador deslizante y micro-interacciones.
class LuxuryBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<LuxuryNavDestination> destinations;

  const LuxuryBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  @override
  State<LuxuryBottomNavBar> createState() => _LuxuryBottomNavBarState();
}

class _LuxuryBottomNavBarState extends State<LuxuryBottomNavBar> {
  double _indicatorIndex = 0;

  @override
  void initState() {
    super.initState();
    _indicatorIndex = widget.selectedIndex.toDouble();
  }

  @override
  void didUpdateWidget(LuxuryBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _indicatorIndex = oldWidget.selectedIndex.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            ...AppTheme.ambientCardShadow,
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: AppColors.surface.withValues(alpha: 0.98),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.95),
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.0),
                          AppColors.primary.withValues(alpha: 0.35),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 64,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth =
                            constraints.maxWidth / widget.destinations.length;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: _indicatorIndex,
                                end: widget.selectedIndex.toDouble(),
                              ),
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              onEnd: () {
                                _indicatorIndex =
                                    widget.selectedIndex.toDouble();
                              },
                              builder: (context, value, _) {
                                return Positioned(
                                  left: value * itemWidth + 6,
                                  top: 6,
                                  bottom: 6,
                                  width: itemWidth - 12,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primary
                                              .withValues(alpha: 0.14),
                                          AppColors.primary
                                              .withValues(alpha: 0.06),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Row(
                              children: List.generate(
                                widget.destinations.length,
                                (index) => _NavItem(
                                  destination: widget.destinations[index],
                                  selected: widget.selectedIndex == index,
                                  isCenter: index ==
                                      widget.destinations.length ~/ 2,
                                  onTap: () {
                                    if (index == widget.selectedIndex) {
                                      return;
                                    }
                                    HapticFeedback.lightImpact();
                                    widget.onSelected(index);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final LuxuryNavDestination destination;
  final bool selected;
  final bool isCenter;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.isCenter,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _pressScale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _pressScale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: widget.selected ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  final iconSize = widget.isCenter
                      ? lerpDouble(22, 26, t)!
                      : lerpDouble(22, 24, t)!;
                  return Transform.scale(
                    scale: lerpDouble(0.94, 1.0, t)!,
                    child: Icon(
                      widget.selected
                          ? widget.destination.selectedIcon
                          : widget.destination.icon,
                      size: iconSize,
                      color: Color.lerp(
                        AppColors.tertiary,
                        AppColors.primary,
                        t,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                style: (widget.selected
                        ? theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          )
                        : theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.w500,
                          )) ??
                    const TextStyle(fontSize: 11),
                child: Text(widget.destination.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
