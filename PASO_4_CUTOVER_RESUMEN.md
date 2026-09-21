# Resumen Fase 4: Cutover Final y Retiro de Firebase

## 1. Acciones Realizadas

### Migración de `AuthRepository` a Supabase Auth (Tarea 4.1)
- **Gestión de Sesión Exclusiva:** Adaptado [auth_repository.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/auth/data/auth_repository.dart) para manejar todo el ciclo de vida de autenticación directamente con `Supabase.instance.client.auth`.
- **Estrategia Multiplataforma de Google Auth:**
  - **Web:** Utiliza flujo de redirección OAuth con `_supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: ...)` y `bootstrapWebSession()` en el arranque para rehidratar la sesión a partir de la URL.
  - **Nativo (Android / iOS):** Autenticación nativa con Google Sign-In (`googleUser.authentication.idToken`) sincronizada directamente en Supabase con `_supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken)`.
- **Stream de Sesión:** `authStateChanges` mapea reactivamente `_supabase.auth.onAuthStateChange` a modelos de dominio `app_model.User`.
- **Sincronización en Postgres (`public.profiles`):** `_syncUserToProfiles` crea o actualiza automáticamente el registro del usuario en la tabla `profiles` mediante `upsert` atómico al autenticarse.
- **Utilidades de Auth:** Migrado [auth_helper.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/utils/auth_helper.dart) para consultar `AppSupabaseClient.client?.auth.currentUser?.id`.

### Limpieza de Branching Dual y Erradicación de Fallbacks Legacy (Tarea 4.2)
- **StorageService:** Suprimido el flag `isSupabaseActive` y la bifurcación dual. Todas las operaciones de subida, obtención de URLs y eliminación (`user-media`, `generated`) operan 100% sobre Supabase Storage buckets.
- **WardrobeRepositoryImpl:** Eliminado el fallback a Firestore. Las prendas se persisten y consultan únicamente en la tabla `wardrobe_items` de Postgres, invocando el worker de visión para cutouts y embeddings.
- **ProfileRepository:** Eliminadas todas las llamadas a `FirebaseFirestore.collection('users')`. Lectura, actualización y guardado de fotos operan sobre `profiles` y `user_photos`.
- **SavedOutfitsRepository:** Todas las operaciones de persistencia relacional operan sobre las tablas `outfits`, `outfit_generations` y `outfit_items` de Supabase.
- **VirtualTryOnService & UserBaseImageService:** Erradicado por completo el SDK cliente `firebase_ai` (Vertex AI). Ambas operaciones se delegan exclusivamente a la Edge Function `ai-router` server-side vía `DeepSeekService`.
- **AppNetworkImage:** Removida la dependencia con `firebase_storage`. Ahora procesa URLs públicas y firmadas con `CachedNetworkImage` estándar.
- **Modelos de Dominio:** Eliminado `import 'package:cloud_firestore/cloud_firestore.dart'` de [wardrobe_item_model.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/wardrobe/domain/wardrobe_item_model.dart) y [saved_outfit_model.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/domain/saved_outfit_model.dart), migrando `Timestamp` a fechas ISO-8601 estándar (`DateTime.tryParse`).

### Paquetes Eliminados de `pubspec.yaml` (Tarea 4.3)
Se eliminaron definitivamente las siguientes 6 dependencias de Firebase:
- `cloud_firestore: ^6.4.1`
- `firebase_ai: ^3.12.1`
- `firebase_auth: ^6.5.1`
- `firebase_core: ^4.9.0`
- `firebase_messaging: ^16.2.2`
- `firebase_storage: ^13.4.1`

### Archivos Legacy Eliminados del Repositorio
- `lib/firebase_options.dart` (configuración legacy del CLI FlutterFire)
- `lib/core/services/firestore_service.dart` (singleton legacy de Firestore)
- `lib/core/services/firebase_ai_service_impl.dart` (reemplazado por `lib/core/services/gateway_ai_service_impl.dart`)
- Gradle plugins eliminados de `android/app/build.gradle.kts` y `android/settings.gradle.kts`.

---

## 2. Bloques de Código Clave

### `lib/main.dart` Limpio
```dart
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
          create: (context) => WardrobeBloc(
            repository: WardrobeRepositoryImpl(),
          ),
        ),
        BlocProvider(
          create: (context) =>
              ChatBloc(repository: StylistRepositoryImpl()),
        ),
        BlocProvider(
          create: (context) => OutfitGenerationBloc(),
        ),
        BlocProvider(
          create: (context) => SavedOutfitsBloc(),
        ),
      ],
      child: MaterialApp.router(
        title: 'AI-Fit',
        theme: AppTheme.darkTheme,
        routerConfig: AppRouter.createRouter(authRepository: authRepository),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

### Extracto de `AuthRepository` con Supabase Auth
```dart
class AuthRepository {
  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    SupabaseClient? supabaseClient,
    GoogleSignIn? googleSignIn,
  })  : _supabase = supabaseClient ?? AppSupabaseClient.client ?? Supabase.instance.client,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  Stream<app_model.User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.asyncMap((data) async {
      final session = data.session;
      final user = session?.user;
      if (user == null) return null;
      return _mapSupabaseUserToAppUser(user);
    });
  }

  Future<app_model.User?> signInWithGoogle() async {
    final user = kIsWeb
        ? await _signInWithGoogleWeb()
        : await _signInWithGoogleNative();

    if (user != null) {
      await _syncUserToProfiles(user);
      return _mapSupabaseUserToAppUser(user);
    }
    return null;
  }

  Future<User?> _signInWithGoogleNative() async {
    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Google Sign-In failed: missing idToken');
    }

    final authResponse = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
    );

    return authResponse.user;
  }

  Future<void> _syncUserToProfiles(User user) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'display_name': user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            user.email?.split('@').first,
        'avatar_path': user.userMetadata?['avatar_url'] ??
            user.userMetadata?['picture'],
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ [AuthRepository] Error al sincronizar con profiles: $e');
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _supabase.auth.signOut();
  }
}
```

---

## 3. Estado de la Compilación

### Salida de `fvm flutter analyze`
```bash
$ fvm flutter analyze
Analyzing AI-Fit...                                             
No issues found! (ran in 2.9s)
```
- **Errores:** 0
- **Advertencias:** 0
- **Linter hints:** 0

### Verificación de Ausencia Residual de Firebase
```bash
$ grep -rn "package:firebase" lib/ || echo "CHECK 1 PASSED: 0 package:firebase imports"
CHECK 1 PASSED: 0 package:firebase imports

$ grep -rn "package:cloud_firestore" lib/ || echo "CHECK 2 PASSED: 0 package:cloud_firestore imports"
CHECK 2 PASSED: 0 package:cloud_firestore imports

$ grep -rn "firebase_" pubspec.yaml || echo "CHECK 3 PASSED: 0 firebase_ in pubspec.yaml"
CHECK 3 PASSED: 0 firebase_ in pubspec.yaml

$ grep -rn "cloud_firestore" pubspec.yaml || echo "CHECK 4 PASSED: 0 cloud_firestore in pubspec.yaml"
CHECK 4 PASSED: 0 cloud_firestore in pubspec.yaml
```

---

## 4. Requerimientos de Acción Humana (Configuración de Google OAuth en Supabase)

Para habilitar el inicio de sesión con Google mediante Supabase Auth en producción, sigue estos pasos en Google Cloud Console y Supabase Dashboard:

### Paso 1: Configurar Credenciales en Google Cloud Console
1. Ingresa a la [Consola de Google Cloud](https://console.cloud.google.com/apis/credentials).
2. Selecciona el proyecto correspondiente a AI-Fit.
3. En **OAuth 2.0 Client IDs**:
   - Para Web: Crea un ID de cliente de aplicación web.
   - En **Authorized JavaScript origins**, agrega:
     - `https://<TU-PROJECT-REF>.supabase.co`
     - `http://localhost:port` (para desarrollo local)
     - Tu dominio de producción web.
   - En **Authorized redirect URIs**, agrega la URL de callback de Supabase:
     - `https://<TU-PROJECT-REF>.supabase.co/auth/v1/callback`
4. Copia el **Client ID** y el **Client Secret**.

### Paso 2: Activar Proveedor Google en el Dashboard de Supabase
1. Ingresa al panel de control de Supabase: `https://supabase.com/dashboard/project/<TU-PROJECT-REF>/auth/providers`.
2. Busca y expande el proveedor **Google**.
3. Activa la casilla **Enable Google provider**.
4. Pega el **Client ID** y el **Client Secret** generados en Google Cloud Console.
5. Haz clic en **Save**.

### Paso 3: Configurar Redirect URLs y Deep Linking
1. En el Dashboard de Supabase, navega a **Authentication -> URL Configuration** (`/auth/url-configuration`).
2. Configura la **Site URL**:
   - Web Staging / Producción: `https://tu-dominio.com` (o `http://localhost:3000` en pruebas locales).
3. En **Redirect URLs**, añade todas las URLs permitidas:
   - Web: `https://tu-dominio.com/**`
   - Desarrollo Web: `http://localhost:*/**`
   - Móvil (Android/iOS): Registra el scheme de la app, por ejemplo:
     - `io.supabase.aifit://login-callback/`
     - `com.example.aifit://auth-callback`
4. Guarda los cambios.
