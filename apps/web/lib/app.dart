import 'dart:async';
import 'dart:js_interop';

import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_bloc.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import 'auth/auth_controller.dart';
import 'data/backend.dart';
import 'pages/item_detail_page.dart';
import 'pages/login_page.dart';
import 'pages/profile_page.dart';
import 'pages/wardrobe_page.dart';

Component _t(String value) => Component.text(value);

/// Raíz de la interfaz: puerta de acceso y rutas con hash (`#/`, `#/prenda/<id>`, `#/perfil`), recargables en cualquier hosting estático.
class App extends StatefulComponent {
  const App({required this.backend, super.key});

  final Backend backend;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthController auth;
  WardrobeBloc? _wardrobe;
  StreamSubscription<Object?>? _wardrobeSubscription;
  String _hash = web.window.location.hash;
  String? _notice;
  Timer? _noticeTimer;
  late final JSFunction _onHashChange = ((web.Event _) {
    if (mounted) setState(() => _hash = web.window.location.hash);
  }).toJS;

  @override
  void initState() {
    super.initState();
    auth = AuthController(component.backend.auth, onChange: _authChanged);
    web.window.addEventListener('hashchange', _onHashChange);
    if (component.backend.available) auth.start();
  }

  @override
  void dispose() {
    web.window.removeEventListener('hashchange', _onHashChange);
    _noticeTimer?.cancel();
    _closeWardrobe();
    auth.dispose();
    super.dispose();
  }

  void _authChanged() {
    if (!mounted) return;
    if (auth.status == AuthStatus.signedIn && _wardrobe == null) {
      final bloc = WardrobeBloc(repository: component.backend.wardrobe);
      _wardrobe = bloc;
      _wardrobeSubscription = bloc.stream.listen((_) {
        if (mounted) setState(() {});
      });
    } else if (auth.status != AuthStatus.signedIn) {
      _closeWardrobe();
    }
    setState(() {});
  }

  void _closeWardrobe() {
    _wardrobeSubscription?.cancel();
    _wardrobe?.close();
    _wardrobe = null;
    _wardrobeSubscription = null;
  }

  void _notify(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'app', [
      _screen(),
      div(classes: 'toast-region', attributes: {'role': 'status', 'aria-live': 'polite'}, [
        if (_notice != null)
          div(classes: 'toast', [
            span([_t(_notice!)]),
            button([_t('Cerrar')], classes: 'btn btn-text', onClick: () => setState(() => _notice = null)),
          ]),
      ]),
    ]);
  }

  Component _screen() {
    if (!component.backend.available) return const UnconfiguredPage();
    final bloc = _wardrobe;
    switch (auth.status) {
      case AuthStatus.starting:
        return main_(id: 'contenido', classes: 'login', [p(classes: 'status', attributes: {'role': 'status'}, [_t('Cargando…')])]);
      case AuthStatus.signedOut:
      case AuthStatus.failed:
        return LoginPage(auth: auth);
      case AuthStatus.signedIn:
        if (bloc == null) return const Component.text('');
        final user = auth.user!;
        final route = _hash.startsWith('#/') ? _hash.substring(2) : '';
        return Component.fragment([
          header(classes: 'bar', [
            p(classes: 'brand', [_t('AIFIT')]),
            nav(attributes: {'aria-label': 'Principal'}, [
              a([_t('Armario')], href: '#/', classes: 'nav-link${route.isEmpty || route.startsWith('prenda') ? ' active' : ''}', attributes: route.isEmpty || route.startsWith('prenda') ? {'aria-current': 'page'} : null),
              a([_t('Perfil')], href: '#/perfil', classes: 'nav-link${route == 'perfil' ? ' active' : ''}', attributes: route == 'perfil' ? {'aria-current': 'page'} : null),
            ]),
            span(classes: 'who', [_t(user.name)]),
            button([_t('Salir')], classes: 'btn', onClick: auth.signOut),
          ]),
          if (route.startsWith('prenda/'))
            ItemDetailPage(bloc: bloc, itemId: Uri.decodeComponent(route.substring('prenda/'.length)), images: component.backend.images, onNotice: _notify, onDeleted: () => web.window.location.hash = '#/')
          else if (route == 'perfil')
            ProfilePage(userId: user.id, load: component.backend.loadProfile, images: component.backend.images)
          else
            WardrobePage(bloc: bloc, images: component.backend.images, onNotice: _notify),
        ]);
    }
  }
}
