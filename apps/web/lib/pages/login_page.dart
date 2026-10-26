import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../auth/auth_controller.dart';

Component _t(String value) => Component.text(value);

class LoginPage extends StatelessComponent {
  const LoginPage({required this.auth, super.key});

  final AuthController auth;

  @override
  Component build(BuildContext context) => main_(id: 'contenido', classes: 'login', [
        p(classes: 'kicker', [_t('AIFIT')]),
        h1([_t('Tu atelier de moda con IA')]),
        p(classes: 'lead', [_t('Armario semántico y try-on virtual. Entra con tu cuenta para ver tus prendas.')]),
        if (auth.error != null) p(classes: 'alert', attributes: {'role': 'alert'}, [_t(auth.error!)]),
        button([_t('Continuar con Google')], classes: 'btn btn-primary btn-large', onClick: auth.signIn),
      ]);
}

/// Se muestra cuando la compilación no trae `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`.
class UnconfiguredPage extends StatelessComponent {
  const UnconfiguredPage({super.key});

  @override
  Component build(BuildContext context) => main_(id: 'contenido', classes: 'login', [
        p(classes: 'kicker', [_t('AIFIT')]),
        h1([_t('Falta configurar Supabase')]),
        p(classes: 'lead', [
          _t('Esta compilación no incluye SUPABASE_URL ni SUPABASE_PUBLISHABLE_KEY. Vuelve a compilarla con '),
          code([_t('--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…')]),
          _t(' (ver docs/SERVER_DEVELOPMENT.md).'),
        ]),
      ]);
}
