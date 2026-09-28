import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/services/onboarding_gate_service.dart';
import '../../../../core/services/onboarding_prefs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_tutorial_overlay.dart';
import '../../../../core/widgets/atelier_wordmark.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

/// Pantalla de bienvenida. El tutorial ya no es un carrusel de texto de 3
/// páginas: se muestra una sola vez como modal (AppTutorialOverlay), y puede
/// reabrirse en cualquier momento desde Perfil (heurística: reconocimiento
/// antes que recuerdo).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorialIfFirstTime());
  }

  Future<void> _showTutorialIfFirstTime() async {
    if (await OnboardingPrefs.hasSeenTips()) return;
    if (!mounted) return;
    await AppTutorialOverlay.show(context);
  }

  Future<void> _finishTips({required bool goToPhotoSetup}) async {
    await OnboardingPrefs.markTipsSeen();
    OnboardingGateService.invalidateCache();

    if (!mounted) return;

    if (!goToPhotoSetup) {
      context.go('/wardrobe');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final hasPhotos = await OnboardingGateService.userHasIdentityPhotos(
        authState.user.id,
      );
      if (!mounted) return;
      if (hasPhotos) {
        context.go('/wardrobe');
        return;
      }
    }

    context.go('/setup-photos');
  }

  Future<void> _onGetStarted() async {
    final seen = await OnboardingPrefs.hasSeenTips();
    if (!mounted) return;
    if (!seen) {
      await AppTutorialOverlay.show(context);
    }
    if (!mounted) return;
    await _finishTips(goToPhotoSetup: true);
  }

  void _skip() {
    _finishTips(goToPhotoSetup: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
              child: Row(
                children: [
                  const AtelierWordmark(
                    fontSize: 22,
                    showRule: false,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      AppStringsEs.skip.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                          ),
                          boxShadow: AppTheme.ambientCardShadow,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Tu estilista de bolsillo',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sube tu identidad y tu armario, y AI-Fit armará looks '
                        'y te mostrará cómo se ven puestos, en segundos.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.secondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _onGetStarted,
                  child: Text(AppStringsEs.getStarted.toUpperCase()),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
