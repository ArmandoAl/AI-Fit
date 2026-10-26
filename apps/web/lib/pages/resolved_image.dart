import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../data/image_resolver.dart';

/// Imagen cuya URL puede requerir firmarse (buckets privados de Supabase). Mientras se resuelve muestra un marcador.
class ResolvedImage extends StatefulComponent {
  const ResolvedImage({required this.source, required this.resolver, required this.alt, this.classes, super.key});

  final String source;
  final ImageResolver? resolver;
  final String alt;
  final String? classes;

  @override
  State<ResolvedImage> createState() => _ResolvedImageState();
}

class _ResolvedImageState extends State<ResolvedImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateComponent(ResolvedImage oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.source != component.source) _resolve();
  }

  void _resolve() {
    final source = component.source;
    final resolver = component.resolver;
    if (resolver == null || ImageResolver.isLoadable(source)) {
      _url = source;
      return;
    }
    _url = null;
    resolver.resolve(source).then((url) {
      if (mounted && component.source == source) setState(() => _url = url);
    });
  }

  @override
  Component build(BuildContext context) {
    final url = _url;
    if (url == null || url.isEmpty) {
      return div(classes: '${component.classes ?? ''} img-placeholder', attributes: {'role': 'img', 'aria-label': url == null ? 'Cargando imagen' : 'Imagen no disponible'}, const []);
    }
    return img(src: url, alt: component.alt, classes: component.classes, attributes: {'loading': 'lazy', 'decoding': 'async'});
  }
}
