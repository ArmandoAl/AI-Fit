import 'dart:async';

import 'package:aifit_core/features/wardrobe/data/wardrobe_repository.dart';
import 'package:aifit_core/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_bloc.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_event.dart';
import 'package:aifit_core/features/wardrobe/presentation/bloc/wardrobe_state.dart';
import 'package:test/test.dart';

WardrobeItem item(String id, String type, {String? cutout, String? status}) =>
    WardrobeItem(id: id, name: id, type: type, subType: id, imageUrl: '$id.jpg', colors: const [], cutoutPath: cutout, processingStatus: status);

class FakeRepository implements WardrobeRepository {
  FakeRepository(this.items);

  List<WardrobeItem> items;
  Object? loadError;
  Object? deleteError;
  final deleted = <List<String>>[];
  int loads = 0;
  final processed = StreamController<WardrobeProcessedUpdate>.broadcast();

  @override
  Future<List<WardrobeItem>> getWardrobeItems() async {
    loads++;
    if (loadError != null) throw loadError!;
    return List.of(items);
  }

  @override
  Future<void> deleteWardrobeItems(List<String> ids) async {
    deleted.add(ids);
    if (deleteError != null) throw deleteError!;
    items = items.where((i) => !ids.contains(i.id)).toList();
  }

  @override
  Future<void> deleteWardrobeItem(String id) => deleteWardrobeItems([id]);

  @override
  Future<void> updateWardrobeItem(WardrobeItem item) async {}

  @override
  Future<void> retryProcessing(WardrobeItem item) async {}

  @override
  Stream<WardrobeProcessedUpdate> get onItemProcessed => processed.stream;
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeRepository repo;
  late WardrobeBloc bloc;

  setUp(() {
    repo = FakeRepository([item('a', 'top'), item('b', 'bottom'), item('c', 'one_piece'), item('d', 'top')]);
  });
  tearDown(() => bloc.close());

  WardrobeLoaded loaded() => bloc.state as WardrobeLoaded;

  test('carga sola al crearse: Loading y luego Loaded con todas las prendas y filtro «All»', () async {
    final states = <WardrobeState>[];
    bloc = WardrobeBloc(repository: repo);
    bloc.stream.listen(states.add);
    await settle();
    expect(states.map((s) => s.runtimeType), [WardrobeLoading, WardrobeLoaded]);
    expect(loaded().allItems.map((i) => i.id), ['a', 'b', 'c', 'd']);
    expect(loaded().selectedCategory, 'All');
  });

  test('un fallo de lectura produce WardrobeError con el mensaje', () async {
    repo.loadError = StateError('sin red');
    bloc = WardrobeBloc(repository: repo);
    await settle();
    expect(bloc.state, isA<WardrobeError>());
    expect((bloc.state as WardrobeError).message, contains('sin red'));
  });

  test('el filtro normaliza categorías y «All» lo restablece', () async {
    bloc = WardrobeBloc(repository: repo);
    await settle();
    bloc.add(const WardrobeFilterChanged('vestido'));
    await settle();
    expect(loaded().filteredItems.map((i) => i.id), ['c']);
    expect(loaded().selectedCategory, 'vestido');
    bloc.add(const WardrobeFilterChanged('top'));
    await settle();
    expect(loaded().filteredItems.map((i) => i.id), ['a', 'd']);
    bloc.add(const WardrobeFilterChanged('All'));
    await settle();
    expect(loaded().filteredItems, hasLength(4));
  });

  test('borrar quita las prendas al instante, conserva el filtro y llama al repositorio', () async {
    bloc = WardrobeBloc(repository: repo);
    await settle();
    bloc.add(const WardrobeFilterChanged('top'));
    await settle();
    bloc.add(const WardrobeItemsDeleted(['a', 'b']));
    await settle();
    expect(loaded().allItems.map((i) => i.id), ['c', 'd']);
    expect(loaded().filteredItems.map((i) => i.id), ['d']);
    expect(loaded().selectedCategory, 'top');
    expect(repo.deleted, [['a', 'b']]);
  });

  test('si el borrado falla se vuelve a leer del servidor', () async {
    repo.deleteError = StateError('403');
    bloc = WardrobeBloc(repository: repo);
    await settle();
    final before = repo.loads;
    bloc.add(const WardrobeItemDeleted('a'));
    await settle();
    expect(repo.loads, before + 1);
    expect(loaded().allItems.map((i) => i.id), ['a', 'b', 'c', 'd'], reason: 'el servidor aún la tiene');
  });

  test('actualización reactiva: cambia el estado y sólo reemplaza el recorte si llega uno', () async {
    repo.items = [item('a', 'top', cutout: 'old.webp', status: 'processing'), item('b', 'top')];
    bloc = WardrobeBloc(repository: repo);
    await settle();
    repo.processed.add(const WardrobeProcessedUpdate(itemId: 'a', status: 'failed'));
    await settle();
    expect(loaded().allItems.first.processingStatus, 'failed');
    expect(loaded().allItems.first.cutoutPath, 'old.webp');
    bloc.add(const WardrobeItemCutoutUpdated(itemId: 'a', cutoutPath: 'new.webp'));
    await settle();
    expect(loaded().allItems.first.cutoutPath, 'new.webp');
    expect(loaded().allItems.first.processingStatus, 'ready');
    expect(loaded().allItems.last.cutoutPath, isNull);
  });

  test('refrescar vuelve a «All» y relee', () async {
    bloc = WardrobeBloc(repository: repo);
    await settle();
    bloc.add(const WardrobeFilterChanged('top'));
    await settle();
    bloc.add(const LoadWardrobeItems());
    await settle();
    expect(loaded().selectedCategory, 'All');
    expect(repo.loads, 2);
  });
}
