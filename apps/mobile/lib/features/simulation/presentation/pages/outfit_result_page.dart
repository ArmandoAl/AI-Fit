import 'package:flutter/material.dart';
import '../../../../core/widgets/app_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../stylist/domain/chat_models.dart';
import '../../../../core/widgets/wearing_items_list.dart';

class OutfitResultPage extends StatelessWidget {
  final GeneratedOutfit outfit;

  const OutfitResultPage({super.key, required this.outfit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.pop(),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface.withValues(alpha: 0.92),
          ),
        ),
        title: Text(
          'Look',
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 2.4,
            color: AppColors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, color: AppColors.onSurface),
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.62,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      imageUrl: outfit.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppStringsEs.matchPercent(outfit.matchPercentage),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: CircleAvatar(
                        backgroundColor: AppColors.surface.withValues(alpha: 0.94),
                        child: IconButton(
                          icon: const Icon(
                            Icons.favorite_border,
                            color: AppColors.primary,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tu look de hoy',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Compuesto con prendas de tu armario',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 24),
            WearingItemsList(itemIds: outfit.itemIds),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Regenerando look...'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('REGENERAR LOOK'),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
