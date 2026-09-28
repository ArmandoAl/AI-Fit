import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_pill_button.dart';
import '../../../wardrobe/domain/wardrobe_item_model.dart';
import '../../../wardrobe/presentation/bloc/wardrobe_bloc.dart';
import '../../../wardrobe/presentation/bloc/wardrobe_state.dart';
import '../../domain/outfit_models.dart';
import '../../services/outfit_service.dart';
import '../widgets/match_score_badge.dart';
import '../widgets/wardrobe_carousel_slot.dart';

/// Pantalla Smart Wardrobe inspirada en el vestidor digital de Cher Horowitz (Clueless)
/// con diseño Dark Glam / Y2K Cyber-Goth (Monster High).
class SmartWardrobeScreen extends StatefulWidget {
  const SmartWardrobeScreen({super.key});

  @override
  State<SmartWardrobeScreen> createState() => _SmartWardrobeScreenState();
}

class _SmartWardrobeScreenState extends State<SmartWardrobeScreen> {
  final OutfitService _outfitService = OutfitService();

  int _selectedTopIndex = 0;
  int _selectedBottomIndex = 0;
  int _selectedShoesIndex = 0;
  int _selectedAccessoryIndex = 0;

  bool _isGeneratingTryOn = false;
  String _loadingTryOnMessage = 'Diseñando tu look Cyber-Goth...';
  Timer? _coldStartTimer1;
  Timer? _coldStartTimer2;

  @override
  void dispose() {
    _coldStartTimer1?.cancel();
    _coldStartTimer2?.cancel();
    super.dispose();
  }

  int _calculateMatchScore({
    required WardrobeItem? top,
    required WardrobeItem? bottom,
    required WardrobeItem? shoes,
    required WardrobeItem? accessory,
  }) {
    if (top == null && bottom == null && shoes == null) return 0;
    int baseScore = 86;

    // Bonificación si hay look completo (top + bottom + shoes)
    if (top != null && bottom != null && shoes != null) {
      baseScore += 6;
    }

    // Evaluación de consistencia cromática
    final selectedColors = <String>{};
    if (top != null) selectedColors.addAll(top.colors.map((c) => c.toLowerCase()));
    if (bottom != null) selectedColors.addAll(bottom.colors.map((c) => c.toLowerCase()));
    if (shoes != null) selectedColors.addAll(shoes.colors.map((c) => c.toLowerCase()));
    if (accessory != null) selectedColors.addAll(accessory.colors.map((c) => c.toLowerCase()));

    // Si comparten o combinan colores clásicos
    if (selectedColors.length <= 3 && selectedColors.isNotEmpty) {
      baseScore += 4;
    }

    // Bonificación accesorio
    if (accessory != null) {
      baseScore += 2;
    }

    return baseScore.clamp(50, 99);
  }

  Future<void> _handleDressMe({
    required List<WardrobeItem> tops,
    required List<WardrobeItem> bottoms,
    required List<WardrobeItem> shoes,
    required List<WardrobeItem> accessories,
    required int matchScore,
  }) async {
    final top = tops.isNotEmpty ? tops[_selectedTopIndex.clamp(0, tops.length - 1)] : null;
    final bottom = bottoms.isNotEmpty ? bottoms[_selectedBottomIndex.clamp(0, bottoms.length - 1)] : null;
    final shoe = shoes.isNotEmpty ? shoes[_selectedShoesIndex.clamp(0, shoes.length - 1)] : null;
    final accessory = accessories.isNotEmpty
        ? accessories[_selectedAccessoryIndex.clamp(0, accessories.length - 1)]
        : null;

    if (top == null || bottom == null || shoe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos Prenda Superior, Inferior y Calzado para el Try-On.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final outfit = GeneratedOutfit(
      id: 'cher_${DateTime.now().millisecondsSinceEpoch}',
      topId: top.id,
      bottomId: bottom.id,
      shoesId: shoe.id,
      outerwearId: accessory?.id,
      matchPercentage: matchScore,
      compatibilityScore: matchScore / 100.0,
      explanation: 'Cher Horowitz 90s Cyber-Goth Look',
      explanationEs: 'Look personalizado armado en el vestidor inteligente de Cher',
    );

    setState(() {
      _isGeneratingTryOn = true;
      _loadingTryOnMessage = 'Diseñando tu look Cyber-Goth...';
    });

    _coldStartTimer1?.cancel();
    _coldStartTimer2?.cancel();

    // Requisito 2: Feedback visual amigable tras 3.5s indicativo de cold start en curso
    _coldStartTimer1 = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isGeneratingTryOn) {
        setState(() {
          _loadingTryOnMessage = 'Despertando al vestidor inteligente... ✨';
        });
      }
    });

    _coldStartTimer2 = Timer(const Duration(milliseconds: 7000), () {
      if (mounted && _isGeneratingTryOn) {
        setState(() {
          _loadingTryOnMessage = 'Preparando los percheros virtuales... 🦇';
        });
      }
    });

    try {
      final intent = OutfitIntent(
        userPrompt: 'Cher Smart Wardrobe Selection',
        styleTags: ['90s', 'cyber-goth', 'glam'],
        preferredColors: top.colors + bottom.colors,
        reasoning: 'Armado interactivo en Smart Wardrobe',
      );

      final wardrobeMap = {
        top.id: top.imageUrl,
        bottom.id: bottom.imageUrl,
        shoe.id: shoe.imageUrl,
        if (accessory != null) accessory.id: accessory.imageUrl,
      };

      // Invocación al gateway server-side
      final tryOnUrl = await _outfitService.generateTryOnForOutfit(
        outfit: outfit,
        intent: intent,
        wardrobeImageUrlsByItemId: wardrobeMap,
      );

      final resultOutfit = (tryOnUrl != null && tryOnUrl.isNotEmpty)
          ? outfit.copyWith(
              metadata: {
                ...?outfit.metadata,
                'tryOnImageUrl': tryOnUrl,
                'imageUrl': tryOnUrl,
              },
            )
          : outfit;

      if (!mounted) return;
      context.push('/outfit-result', extra: resultOutfit);
    } catch (e) {
      if (!mounted) return;
      // Navegación directa con fallback si falla la generación visual
      context.push('/outfit-result', extra: outfit);
    } finally {
      _coldStartTimer1?.cancel();
      _coldStartTimer2?.cancel();
      if (mounted) {
        setState(() => _isGeneratingTryOn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.neonMagenta, size: 18),
            const SizedBox(width: 8),
            Text(
              "CHER'S SMART CLOSET",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    color: AppColors.neonMagenta.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.checkroom_outlined, color: AppColors.neonMint),
            tooltip: 'Ver Outfits Guardados',
            onPressed: () => context.push('/saved-outfits'),
          ),
        ],
      ),
      body: BlocBuilder<WardrobeBloc, WardrobeState>(
        builder: (context, state) {
          if (state is WardrobeLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.neonMagenta),
            );
          }

          if (state is WardrobeError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error al cargar el vestidor: ${state.message}',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allItems = state is WardrobeLoaded ? state.allItems : <WardrobeItem>[];

          // Clasificación de prendas en los 4 slots
          final tops = allItems.where((i) {
            final cat = i.type.toLowerCase();
            return cat == 'top' || cat == 'shirt' || cat == 't-shirt' || cat == 'blouse' || cat == 'sweater';
          }).toList();

          final bottoms = allItems.where((i) {
            final cat = i.type.toLowerCase();
            return cat == 'bottom' || cat == 'pants' || cat == 'skirt' || cat == 'jeans' || cat == 'shorts';
          }).toList();

          final shoes = allItems.where((i) {
            final cat = i.type.toLowerCase();
            return cat == 'shoes' || cat == 'sneakers' || cat == 'boots' || cat == 'heels' || cat == 'footwear';
          }).toList();

          final accessories = allItems.where((i) {
            final cat = i.type.toLowerCase();
            return cat == 'outerwear' || cat == 'accessory' || cat == 'accessories' || cat == 'jacket' || cat == 'one-piece';
          }).toList();

          final currentTop = tops.isNotEmpty ? tops[_selectedTopIndex.clamp(0, tops.length - 1)] : null;
          final currentBottom = bottoms.isNotEmpty ? bottoms[_selectedBottomIndex.clamp(0, bottoms.length - 1)] : null;
          final currentShoes = shoes.isNotEmpty ? shoes[_selectedShoesIndex.clamp(0, shoes.length - 1)] : null;
          final currentAccessory = accessories.isNotEmpty
              ? accessories[_selectedAccessoryIndex.clamp(0, accessories.length - 1)]
              : null;

          final matchScore = _calculateMatchScore(
            top: currentTop,
            bottom: currentBottom,
            shoes: currentShoes,
            accessory: currentAccessory,
          );

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Slot 1: TOP
                  WardrobeCarouselSlot(
                    title: '1. TOP // PRENDA SUPERIOR',
                    categoryIcon: Icons.dry_cleaning_rounded,
                    items: tops,
                    selectedIndex: _selectedTopIndex,
                    onItemChanged: (idx) => setState(() => _selectedTopIndex = idx),
                    emptyMessage: 'No hay prendas superiores guardadas',
                    onAddRequested: () => context.push('/wardrobe'),
                  ),
                  const SizedBox(height: 12),

                  // Slot 2: BOTTOM
                  WardrobeCarouselSlot(
                    title: '2. BOTTOM // PRENDA INFERIOR',
                    categoryIcon: Icons.view_column_rounded,
                    items: bottoms,
                    selectedIndex: _selectedBottomIndex,
                    onItemChanged: (idx) => setState(() => _selectedBottomIndex = idx),
                    emptyMessage: 'No hay prendas inferiores guardadas',
                    onAddRequested: () => context.push('/wardrobe'),
                  ),
                  const SizedBox(height: 12),

                  // Slot 3: SHOES
                  WardrobeCarouselSlot(
                    title: '3. SHOES // CALZADO',
                    categoryIcon: Icons.roller_skating_rounded,
                    items: shoes,
                    selectedIndex: _selectedShoesIndex,
                    onItemChanged: (idx) => setState(() => _selectedShoesIndex = idx),
                    emptyMessage: 'No hay calzado guardado',
                    onAddRequested: () => context.push('/wardrobe'),
                  ),
                  const SizedBox(height: 12),

                  // Slot 4: ACCESSORY / ONE-PIECE
                  WardrobeCarouselSlot(
                    title: '4. ACCESORIOS & ABRIGOS',
                    categoryIcon: Icons.flare_rounded,
                    items: accessories,
                    selectedIndex: _selectedAccessoryIndex,
                    onItemChanged: (idx) => setState(() => _selectedAccessoryIndex = idx),
                    emptyMessage: 'Opcional: agrega accesorios o chaquetas',
                    onAddRequested: () => context.push('/wardrobe'),
                  ),
                  const SizedBox(height: 20),

                  // Badge de Compatibilidad "Match Score"
                  MatchScoreBadge(score: matchScore),
                  const SizedBox(height: 24),

                  // Botón Principal de Acción "DRESS ME"
                  GradientPillButton(
                    text: '⚡ DRESS ME (TRY-ON)',
                    isLoading: _isGeneratingTryOn,
                    height: 56,
                    icon: const Icon(Icons.bolt_rounded, size: 22),
                    onPressed: () => _handleDressMe(
                      tops: tops,
                      bottoms: bottoms,
                      shoes: shoes,
                      accessories: accessories,
                      matchScore: matchScore,
                    ),
                  ),
                  if (_isGeneratingTryOn) ...[
                    const SizedBox(height: 14),
                    Container(
                      key: const ValueKey('cold_start_loading_banner'),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.neonMagenta.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonMagenta.withValues(alpha: 0.25),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonMint),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: Text(
                                _loadingTryOnMessage,
                                key: ValueKey(_loadingTryOnMessage),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
