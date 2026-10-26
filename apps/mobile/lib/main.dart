import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/bootstrap/web_auth_bootstrap.dart';
import 'core/services/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/wardrobe/presentation/bloc/wardrobe_bloc.dart';
import 'features/wardrobe/data/wardrobe_repository_impl.dart';
import 'features/stylist/presentation/bloc/chat_bloc.dart';
import 'features/stylist/data/stylist_repository_impl.dart';
import 'features/outfit/presentation/bloc/outfit_generation_bloc.dart';
import 'features/outfit/presentation/bloc/saved_outfits_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await AppSupabaseClient.initialize();

  final authRepository = AuthRepository();
  if (kIsWeb) {
    await WebAuthBootstrap.initialize(authRepository);
  }

  runApp(AIFitApp(authRepository: authRepository));
}

class AIFitApp extends StatelessWidget {
  const AIFitApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(authRepository: authRepository),
        ),
        BlocProvider(
          create: (context) =>
              WardrobeBloc(repository: WardrobeRepositoryImpl()),
        ),
        BlocProvider(
          create: (context) => ChatBloc(repository: StylistRepositoryImpl()),
        ),
        BlocProvider(create: (context) => OutfitGenerationBloc()),
        BlocProvider(create: (context) => SavedOutfitsBloc()),
      ],
      child: Builder(
        builder: (context) {
          // Ahora este context SÍ tiene acceso a los BlocProviders
          return MaterialApp.router(
            title: 'AIFit Atelier',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            routerConfig: createRouter(context),
          );
        },
      ),
    );
  }
}
