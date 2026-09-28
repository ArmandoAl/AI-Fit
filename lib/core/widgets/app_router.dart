import 'dart:async';
import 'package:aifit/features/auth/presentation/pages/login_page.dart';
import 'package:aifit/features/auth/presentation/pages/welcome_page.dart';
import 'package:aifit/features/auth/presentation/pages/photo_setup_page.dart';
import 'package:aifit/features/profile/presentation/pages/profile_page.dart';
import 'package:aifit/features/simulation/presentation/pages/outfit_result_page.dart';
import 'package:aifit/features/stylist/presentation/pages/stylist_page.dart';
import 'package:aifit/features/wardrobe/presentation/pages/wardrobe_page.dart';
import 'package:aifit/features/outfit/presentation/pages/generate_outfit_page.dart';
import 'package:aifit/features/outfit/presentation/pages/saved_outfits_page.dart';
import 'package:aifit/features/outfit/presentation/screens/smart_wardrobe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../widgets/main_layout.dart';
import '../widgets/shell_tab_transition.dart';
import '../../core/services/onboarding_gate_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/stylist/domain/chat_models.dart' as chat_models;
import '../../features/outfit/domain/outfit_models.dart' as outfit_models;

// Definimos una clave global para el navegador
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Helper class para convertir Stream en Listenable para GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter(BuildContext context) {
  final authBloc = context.read<AuthBloc>();

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) async {
      final authState = authBloc.state;
      final currentLocation = state.matchedLocation;

      // Solo el arranque inicial usa splash; login en curso no debe sacar al usuario.
      if (authState is AuthLoading) {
        if (currentLocation == '/login' || currentLocation == '/splash') {
          return null;
        }
        return '/splash';
      }

      if (authState is AuthSigningIn) {
        return null;
      }

      if (authState is AuthUnauthenticated) {
        if (currentLocation == '/login' ||
            currentLocation == '/welcome' ||
            currentLocation == '/setup-photos') {
          return null;
        }
        return '/login';
      }

      if (authState is AuthAuthenticated) {
        final userId = authState.user.id;

        if (currentLocation == '/splash' || currentLocation == '/login') {
          return OnboardingGateService.initialRouteFor(userId);
        }

        final blocked = await OnboardingGateService.redirectIfOnboardingComplete(
          userId,
          currentLocation,
        );
        if (blocked != null) return blocked;
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Login Page
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

      // Welcome/Onboarding
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),

      // Photo Setup
      GoRoute(
        path: '/setup-photos',
        builder: (context, state) => const PhotoSetupPage(),
      ),
      // Shell Route (Barra de Navegación Inferior)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayout(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Wardrobe
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wardrobe',
                pageBuilder: (context, state) => shellTabTransitionPage(
                  key: state.pageKey,
                  child: const WardrobePage(),
                ),
              ),
            ],
          ),
          // Branch 2: Stylist / Chat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stylist',
                pageBuilder: (context, state) => shellTabTransitionPage(
                  key: state.pageKey,
                  child: const StylistPage(),
                ),
              ),
            ],
          ),
          // Branch 3: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => shellTabTransitionPage(
                  key: state.pageKey,
                  child: const ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Ruta hija para generar outfits (fuera del bottom nav)
      GoRoute(
        path: '/generate-outfit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GenerateOutfitPage(),
      ),
      // Ruta para Smart Wardrobe de Cher (Clueless x Monster High)
      GoRoute(
        path: '/smart-wardrobe',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SmartWardrobeScreen(),
      ),
      // Ruta hija para outfits guardados (fuera del bottom nav)
      GoRoute(
        path: '/saved-outfits',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedOutfitsPage(),
      ),
      // Ruta hija para resultados (fuera del bottom nav)
      GoRoute(
        path: '/outfit-result',
        parentNavigatorKey: _rootNavigatorKey, // Para cubrir la bottom bar
        builder: (context, state) {
          final extra = state.extra;
          if (extra is chat_models.GeneratedOutfit) {
            return OutfitResultPage(outfit: extra);
          } else if (extra is outfit_models.GeneratedOutfit) {
            final imageUrl = extra.metadata?['tryOnImageUrl']?.toString() ??
                extra.metadata?['imageUrl']?.toString() ??
                '';
            return OutfitResultPage(
              outfit: chat_models.GeneratedOutfit(
                id: extra.id,
                imageUrl: imageUrl,
                matchPercentage: extra.matchPercentage,
                itemIds: extra.itemIds,
              ),
            );
          } else if (extra is Map<String, dynamic>) {
            return OutfitResultPage(
              outfit: chat_models.GeneratedOutfit.fromJson(extra),
            );
          }
          throw ArgumentError('Formato de outfit no soportado en /outfit-result: $extra');
        },
      ),
    ],
  );
}
