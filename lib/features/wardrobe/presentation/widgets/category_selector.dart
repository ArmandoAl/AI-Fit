import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/wardrobe_palette.dart';

/// Selector visual interactivo de categorías para AI-Fit con estética Dark Glam / Y2K Cyber-Goth.
/// Soporta 'top', 'bottom', 'one_piece', 'shoes', 'outerwear', 'accessories' (y opcionalmente 'All').
class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final List<String>? categories;
  final bool isFilter;
  final EdgeInsetsGeometry padding;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.categories,
    this.isFilter = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  });

  static const List<String> defaultCategories = [
    'top',
    'bottom',
    'one_piece',
    'shoes',
    'outerwear',
    'accessories',
  ];

  static const List<String> defaultFilterCategories = [
    'All',
    'top',
    'bottom',
    'one_piece',
    'shoes',
    'outerwear',
    'accessories',
  ];

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.auto_awesome_rounded;
      case 'top':
        return Icons.checkroom_rounded;
      case 'bottom':
        return Icons.straighten_rounded;
      case 'one_piece':
      case 'one-piece':
        return Icons.woman_rounded;
      case 'shoes':
        return Icons.roller_skating_rounded;
      case 'outerwear':
        return Icons.layers_rounded;
      case 'accessories':
      case 'accessory':
        return Icons.local_mall_rounded;
      default:
        return Icons.style_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = categories ?? (isFilter ? defaultFilterCategories : defaultCategories);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Row(
        children: list.map((category) {
          final isSelected = selectedCategory.toLowerCase() == category.toLowerCase();
          final label = category.toLowerCase() == 'all'
              ? 'Todos'
              : WardrobePalette.labelType(category);
          final icon = getCategoryIcon(category);

          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: InkWell(
              onTap: () => onCategorySelected(category),
              borderRadius: BorderRadius.circular(16.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.surface
                      : AppColors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: isSelected
                        ? (category == 'one_piece'
                            ? AppColors.neonMagenta
                            : (category == 'accessories'
                                ? AppColors.neonMint
                                : AppColors.neonMagenta))
                        : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (category == 'accessories'
                                    ? AppColors.neonMint
                                    : AppColors.neonMagenta)
                                .withValues(alpha: 0.25),
                            blurRadius: 10.0,
                            spreadRadius: 1.0,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16.0,
                      color: isSelected
                          ? (category == 'accessories'
                              ? AppColors.neonMint
                              : AppColors.neonMagenta)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 7.0),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontSize: 13.0,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
