import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/glowing_border_card.dart';
import '../../../wardrobe/domain/wardrobe_item_model.dart';

/// Slot individual interactivo tipo carrusel (Cher Horowitz Clueless Wardrobe).
///
/// Permite explorar horizontalmente prendas de una categoría específica
/// usando flechas táctiles `[ < ]` y `[ > ]` o deslizamiento directo (`PageView`).
class WardrobeCarouselSlot extends StatefulWidget {
  const WardrobeCarouselSlot({
    super.key,
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onItemChanged,
    this.categoryIcon = Icons.checkroom,
    this.height = 160.0,
    this.emptyMessage = 'Sin prendas en esta categoría',
    this.onAddRequested,
  });

  final String title;
  final List<WardrobeItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemChanged;
  final IconData categoryIcon;
  final double height;
  final String emptyMessage;
  final VoidCallback? onAddRequested;

  @override
  State<WardrobeCarouselSlot> createState() => _WardrobeCarouselSlotState();
}

class _WardrobeCarouselSlotState extends State<WardrobeCarouselSlot> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialPage = widget.items.isEmpty
        ? 0
        : widget.selectedIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void didUpdateWidget(covariant WardrobeCarouselSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isNotEmpty &&
        widget.selectedIndex != oldWidget.selectedIndex &&
        _pageController.hasClients) {
      final targetPage = widget.selectedIndex.clamp(0, widget.items.length - 1);
      if (_pageController.page?.round() != targetPage) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (widget.items.isEmpty) return;
    final newIndex = widget.selectedIndex > 0
        ? widget.selectedIndex - 1
        : widget.items.length - 1; // Ciclo continuo estilo Clueless
    _animateToIndex(newIndex);
  }

  void _goToNext() {
    if (widget.items.isEmpty) return;
    final newIndex = widget.selectedIndex < widget.items.length - 1
        ? widget.selectedIndex + 1
        : 0; // Ciclo continuo
    _animateToIndex(newIndex);
  }

  void _animateToIndex(int index) {
    widget.onItemChanged(index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    final currentIndex = count == 0 ? 0 : widget.selectedIndex.clamp(0, count - 1);
    final currentItem = count > 0 ? widget.items[currentIndex] : null;

    return GlowingBorderCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SizedBox(
        height: widget.height,
        child: Column(
          children: [
            // Cabecera del Slot: Título, ícono y contador
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.categoryIcon,
                      size: 14,
                      color: AppColors.neonMagenta,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.title.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${currentIndex + 1}/$count',
                      style: const TextStyle(
                        color: AppColors.neonMint,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Visor central con flechas
            Expanded(
              child: Row(
                children: [
                  // Flecha Izquierda [ < ]
                  _buildNavArrow(
                    icon: Icons.chevron_left_rounded,
                    onPressed: count > 1 ? _goToPrevious : null,
                  ),

                  // Visor central de prenda
                  Expanded(
                    child: count == 0
                        ? _buildEmptyState()
                        : PageView.builder(
                            controller: _pageController,
                            onPageChanged: widget.onItemChanged,
                            itemCount: count,
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              return _buildGarmentDisplay(item);
                            },
                          ),
                  ),

                  // Flecha Derecha [ > ]
                  _buildNavArrow(
                    icon: Icons.chevron_right_rounded,
                    onPressed: count > 1 ? _goToNext : null,
                  ),
                ],
              ),
            ),

            // Pie de información de la prenda
            if (currentItem != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  currentItem.name.isNotEmpty
                      ? currentItem.name
                      : currentItem.subType.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavArrow({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        splashColor: AppColors.neonMagenta.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEnabled
                ? AppColors.surfaceContainerHigh.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 26,
            color: isEnabled ? AppColors.neonMagenta : AppColors.accentInactive.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildGarmentDisplay(WardrobeItem item) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: AppNetworkImage(
          imageUrl: item.imageUrl,
          fit: BoxFit.contain,
          placeholder: Container(
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.neonMint,
              ),
            ),
          ),
          errorWidget: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.checkroom_outlined,
                  color: AppColors.accentInactive,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return InkWell(
      onTap: widget.onAddRequested,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.neonMint.withValues(alpha: 0.8),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
