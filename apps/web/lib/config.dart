/// Configuración de compilación (`--dart-define`). Es pública: la llave «publishable» de Supabase va al navegador;
/// la seguridad la dan las políticas RLS del proyecto, no el secreto de esta llave.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseKey, this.fakeBackend = false});

  static const fromEnvironment = AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY')),
    // Datos sintéticos para pruebas visuales sin backend. Con el valor por defecto (false) el compilador elimina ese código.
    fakeBackend: bool.fromEnvironment('AIFIT_FAKE_BACKEND'),
  );

  final String supabaseUrl;
  final String supabaseKey;
  final bool fakeBackend;

  bool get configured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
