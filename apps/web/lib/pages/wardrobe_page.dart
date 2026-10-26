import 'package:aifit_core/core/l10n/app_strings_es.dart';
import 'package:aifit_core/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:aifit_core/features/wardrobe/domain/wardrobe_palette.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_bloc.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_event.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_state.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../data/image_resolver.dart';
import '../platform/dialogs.dart';
import 'resolved_image.dart';

Component _t(String value) => Component.text(value);

const _filterKeys = ['All', 'top', 'bottom', 'one_piece', 'shoes', 'outerwear', 'accessories'];
String _filterLabel(String key) => key == 'All' ? AppStringsEs.filterAll : WardrobePalette.labelType(key);

/// Armario: filtros por categoría, cuadrícula, selección múltiple y borrado. Misma lógica (WardrobeBloc) que la app móvil.
class WardrobePage extends StatefulComponent {
  const WardrobePage({required this.bloc, required this.images, required this.onNotice, super.key});

  final WardrobeBloc bloc;
  final ImageResolver? images;
  final void Function(String message) onNotice;

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final _selected = <String>{};
  bool _deleting = false;

  WardrobeBloc get bloc => component.bloc;

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await confirmDestructive(
      title: count == 1 ? '¿Eliminar prenda?' : '¿Eliminar $count prendas?',
      description: 'Esta acción eliminará las prendas seleccionadas de tu armario de forma permanente.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await bloc.deleteItems(_selected.toList());
      _selected.clear();
      component.onNotice(count == 1 ? 'Prenda eliminada' : '$count prendas eliminadas');
    } on Object catch (e) {
      component.onNotice('No se pudieron eliminar las prendas: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Component build(BuildContext context) {
    final state = bloc.state;
    final selecting = _selected.isNotEmpty;
    final total = state is WardrobeLoaded ? state.allItems.length : 0;
    return Component.fragment([
      if (selecting)
        div(classes: 'selection-bar', attributes: {'role': 'region', 'aria-label': 'Modo selección'}, [
          button([_t('Cancelar')], classes: 'btn', attributes: {'aria-label': 'Cancelar selección'}, onClick: () => setState(_selected.clear)),
          span(classes: 'bar-title', attributes: {'role': 'status'}, [_t(_selected.length == 1 ? '1 seleccionada' : '${_selected.length} seleccionadas')]),
          button([_t(_deleting ? 'Eliminando…' : 'Eliminar')], classes: 'btn btn-danger', disabled: _deleting, onClick: _deleteSelected),
        ]),
      main_(id: 'contenido', [
        div(classes: 'tabs', attributes: {'role': 'tablist'}, [
          button([_t('Prendas · $total')], classes: 'tab active', attributes: {'role': 'tab', 'aria-selected': 'true'}),
          button([_t('Looks')], classes: 'tab', disabled: true, attributes: {'role': 'tab', 'title': 'Los looks guardados aún no están en la web'}),
        ]),
        div(classes: 'chips', attributes: {'role': 'group', 'aria-label': 'Filtrar por categoría'}, [
          for (final key in _filterKeys)
            button(
              [_t(_filterLabel(key).toUpperCase())],
              classes: 'chip${state is WardrobeLoaded && state.selectedCategory.toLowerCase() == key.toLowerCase() ? ' active' : ''}',
              attributes: {'aria-pressed': '${state is WardrobeLoaded && state.selectedCategory.toLowerCase() == key.toLowerCase()}'},
              onClick: () => bloc.add(WardrobeFilterChanged(key)),
            ),
        ]),
        _body(state),
      ]),
    ]);
  }

  Component _body(WardrobeState state) {
    if (state is WardrobeLoading || state is WardrobeInitial) {
      return p(classes: 'status', attributes: {'role': 'status'}, [_t('Cargando prendas…')]);
    }
    if (state is WardrobeError) {
      return div(classes: 'empty', attributes: {'role': 'alert'}, [
        h2([_t(AppStringsEs.error)]),
        p([_t(state.message)]),
        button([_t('Reintentar')], classes: 'btn', onClick: () => bloc.add(const LoadWardrobeItems())),
      ]);
    }
    // `WardrobeState.items` devuelve todas las prendas; lo visible es la lista filtrada (igual que la app móvil).
    final items = state is WardrobeLoaded ? state.filteredItems : const <WardrobeItem>[];
    if (items.isEmpty) {
      return div(classes: 'empty', [
        h2([_t(AppStringsEs.emptyWardrobeTitle)]),
        p([_t(AppStringsEs.emptyWardrobeSubtitle)]),
        p(classes: 'note', [_t('Por ahora las prendas se añaden desde la app móvil; aquí las ves y las administras.')]),
      ]);
    }
    return ul(classes: 'grid', attributes: {'role': 'list'}, [
      for (final item in items) li(key: ValueKey(item.id), [_card(item)]),
    ]);
  }

  Component _card(WardrobeItem item) {
    final selecting = _selected.isNotEmpty;
    final isSelected = _selected.contains(item.id);
    return div(classes: 'card${isSelected ? ' selected' : ''}', [
      a(
        href: '#/prenda/${Uri.encodeComponent(item.id)}',
        classes: 'card-open',
        attributes: {'aria-label': 'Abrir ${item.name}'},
        // Con la selección activa, tocar la prenda la marca en lugar de abrirla (igual que la app móvil).
        events: {
          'click': (event) {
            if (selecting) {
              event.preventDefault();
              _toggle(item.id);
            }
          },
        },
        [
          ResolvedImage(source: item.displayImageUrl, resolver: component.images, alt: item.name, classes: 'card-img'),
          div(classes: 'card-info', [
            span(classes: 'card-name', [_t(item.name)]),
            span(classes: 'card-sub', [_t(WardrobePalette.labelSubtype(item.subType))]),
          ]),
        ],
      ),
      if (item.isProcessing) span(classes: 'badge badge-info', [_t('Procesando…')]),
      if (item.processingFailed) span(classes: 'badge badge-error', [_t('Falló el procesamiento')]),
      label(classes: 'check', [
        input(
          type: InputType.checkbox,
          checked: isSelected,
          attributes: {'aria-label': 'Seleccionar ${item.name}'},
          events: {'change': (_) => _toggle(item.id)},
        ),
      ]),
    ]);
  }
}
