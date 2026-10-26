import 'package:aifit_core/features/profile/domain/user_identity_profile.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../data/image_resolver.dart';
import 'resolved_image.dart';

Component _t(String value) => Component.text(value);

/// Perfil de la persona (sólo lectura): datos básicos, estado del onboarding e identidad visual analizada.
class ProfilePage extends StatefulComponent {
  const ProfilePage({required this.userId, required this.load, required this.images, super.key});

  final String userId;
  final Future<Map<String, dynamic>?> Function(String userId) load;
  final ImageResolver? images;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    component.load(component.userId).then((value) {
      if (!mounted) return;
      setState(() {
        _profile = value;
        _loading = false;
      });
    }).catchError((Object _) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    });
  }

  @override
  Component build(BuildContext context) {
    if (_loading) return main_(id: 'contenido', [p(classes: 'status', attributes: {'role': 'status'}, [_t('Cargando perfil…')])]);
    if (_failed) return main_(id: 'contenido', [p(classes: 'status', attributes: {'role': 'alert'}, [_t('No se pudo cargar el perfil.')])]);
    final profile = _profile;
    if (profile == null) return main_(id: 'contenido', [p(classes: 'status', attributes: {'role': 'status'}, [_t('Aún no hay un perfil para esta cuenta.')])]);
    final identity = profile['identityProfile'] is Map ? IdentityProfile.fromJson(Map<String, dynamic>.from(profile['identityProfile'] as Map)) : null;
    final body = (profile['bodyPhotos'] as List?)?.length ?? 0, face = (profile['facePhotos'] as List?)?.length ?? 0;
    List<Component> row(String title, String? value) => value == null || value.isEmpty ? const [] : [dt([_t(title)]), dd([_t(value)])];
    return main_(id: 'contenido', classes: 'profile', [
      div(classes: 'profile-head', [
        if ((profile['avatarUrl'] ?? '').toString().isNotEmpty)
          ResolvedImage(source: profile['avatarUrl'].toString(), resolver: component.images, alt: 'Foto de perfil', classes: 'avatar'),
        h1([_t((profile['displayName'] ?? 'Mi perfil').toString())]),
      ]),
      dl([
        ...row('Onboarding', profile['onboardingCompleted'] == true ? 'Completado' : 'Pendiente'),
        ...row('Fotos de cuerpo', '$body'),
        ...row('Fotos de rostro', '$face'),
      ]),
      if (identity != null) ...[
        h2([_t('Identidad visual')]),
        dl([
          ...row('Tono de piel', [identity.skinTone?.primary, identity.skinTone?.undertone].whereType<String>().join(' · ')),
          ...row('Rostro', [identity.face?.shape, identity.face?.jawDefinition, identity.face?.eyeShape, identity.face?.noseShape].whereType<String>().join(' · ')),
          ...row('Cabello', [identity.hair?.color, identity.hair?.style, identity.hair?.density].whereType<String>().join(' · ')),
          ...row('Cuerpo', [identity.body?.type, identity.body?.build, identity.body?.proportions, identity.body?.heightEstimate].whereType<String>().join(' · ')),
        ]),
      ],
    ]);
  }
}
