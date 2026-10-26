import 'package:aifit_core/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:aifit_core/features/wardrobe/domain/wardrobe_palette.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_bloc.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_state.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../data/image_resolver.dart';
import '../platform/dialogs.dart';
import 'resolved_image.dart';

Component _t(String value) => Component.text(value);

/// Ficha de una prenda (sólo lectura en esta primera versión web) con opción de eliminarla.
class ItemDetailPage extends StatelessComponent {
  const ItemDetailPage({required this.bloc, required this.itemId, required this.images, required this.onDeleted, required this.onNotice, super.key});

  final WardrobeBloc bloc;
  final String itemId;
  final ImageResolver? images;
  final void Function() onDeleted;
  final void Function(String message) onNotice;

  Future<void> _delete(WardrobeItem item) async {
    final confirmed = await confirmDestructive(
      title: '¿Eliminar prenda?',
      description: 'Esta acción eliminará las prendas seleccionadas de tu armario de forma permanente.',
    );
    if (!confirmed) return;
    try {
      await bloc.deleteItems([item.id]);
      onNotice('Prenda eliminada');
      onDeleted();
    } on Object catch (e) {
      onNotice('No se pudieron eliminar las prendas: $e');
    }
  }

  @override
  Component build(BuildContext context) {
    final state = bloc.state;
    if (state is! WardrobeLoaded) {
      return main_(id: 'contenido', [p(classes: 'status', attributes: {'role': 'status'}, [_t(state is WardrobeError ? 'No se pudo cargar la prenda.' : 'Cargando prenda…')])]);
    }
    final item = state.allItems.where((candidate) => candidate.id == itemId).firstOrNull;
    if (item == null) {
      return main_(id: 'contenido', [
        a([_t('← Armario')], href: '#/', classes: 'btn'),
        p(classes: 'status', attributes: {'role': 'status'}, [_t('La prenda ya no existe.')]),
      ]);
    }
    List<Component> row(String title, Iterable<String> values) =>
        values.isEmpty ? const [] : [dt([_t(title)]), dd([_t(values.join(', '))])];
    return main_(id: 'contenido', classes: 'detail', [
      div(classes: 'detail-bar', [
        a([_t('← Armario')], href: '#/', classes: 'btn'),
        button([_t('Eliminar')], classes: 'btn btn-danger', onClick: () => _delete(item)),
      ]),
      div(classes: 'detail-body', [
        ResolvedImage(source: item.displayImageUrl, resolver: images, alt: item.name, classes: 'detail-img'),
        div([
          h1([_t(item.name)]),
          if (item.isProcessing) p(classes: 'badge badge-info inline', [_t('Procesando…')]),
          if (item.processingFailed) p(classes: 'badge badge-error inline', [_t('Falló el procesamiento: reintenta desde la app')]),
          dl([
            ...row('Categoría', [WardrobePalette.labelType(item.type)]),
            ...row('Tipo', [WardrobePalette.labelSubtype(item.subType)]),
            ...row('Colores', item.colors.map(WardrobePalette.labelColor)),
            ...row('Estilo', item.styleTags.map(WardrobePalette.labelStyleTag)),
            ...row('Temporada', item.season.map(WardrobePalette.labelSeason)),
            ...row('Marca', [if (item.brand != null && item.brand!.isNotEmpty) item.brand!]),
            ...row('Agregada', [if (item.createdAt != null) _date(item.createdAt!)]),
          ]),
          if (item.aiMetadata != null) p(classes: 'note', [_t('Esta prenda tiene análisis de IA; el detalle completo se ve en la app.')]),
        ]),
      ]),
    ]);
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }
}
