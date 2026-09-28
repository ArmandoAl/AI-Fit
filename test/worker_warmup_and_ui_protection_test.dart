import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aifit/core/services/worker_warmup_service.dart';
import 'package:aifit/core/widgets/wardrobe_item_card.dart';
import 'package:aifit/features/wardrobe/presentation/pages/wardrobe_page.dart';
import 'package:aifit/features/wardrobe/presentation/bloc/wardrobe_bloc.dart';
import 'package:aifit/features/wardrobe/presentation/bloc/wardrobe_event.dart';
import 'package:aifit/features/wardrobe/presentation/bloc/wardrobe_state.dart';
import 'package:aifit/features/wardrobe/data/wardrobe_repository.dart';
import 'package:aifit/features/wardrobe/domain/wardrobe_item_model.dart';

class _FakeWardrobeRepository implements WardrobeRepository {
  final _controller = StreamController<WardrobeProcessedUpdate>.broadcast();
  final List<WardrobeItem> items;
  final List<String> deletedIds = [];

  _FakeWardrobeRepository({List<WardrobeItem>? items}) : items = items ?? [];

  @override
  Future<List<WardrobeItem>> getWardrobeItems() async => items;

  @override
  Future<void> updateWardrobeItem(WardrobeItem item) async {}

  @override
  Future<void> retryProcessing(WardrobeItem item) async {}

  @override
  Future<void> deleteWardrobeItem(String id) async {}

  @override
  Future<void> deleteWardrobeItems(List<String> ids) async {
    deletedIds.addAll(ids);
    items.removeWhere((item) => ids.contains(item.id));
  }

  @override
  Stream<WardrobeProcessedUpdate> get onItemProcessed => _controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkerWarmupService Tests', () {
    test(
      'WorkerWarmupService.warmUp executes non-blocking and traps errors safely',
      () async {
        // Debería ejecutarse sin arrojar excepciones
        expect(() => WorkerWarmupService.warmUp(), returnsNormally);

        // triggerWarmUp directo también debe manejar cualquier falla de red sin explotar
        await expectLater(
          WorkerWarmupService.instance.triggerWarmUp(),
          completes,
        );
      },
    );

    test('WorkerWarmupService healthUrl points to /health endpoint', () {
      expect(WorkerWarmupService.healthUrl, endsWith('/health'));
      expect(WorkerWarmupService.healthUrl, contains('aifit-image-worker'));
    });
  });

  group('WardrobePage Warmup Protection UI Tests', () {
    late WardrobeBloc wardrobeBloc;
    late _FakeWardrobeRepository repository;

    setUp(() {
      repository = _FakeWardrobeRepository();
      wardrobeBloc = WardrobeBloc(repository: repository);
    });

    tearDown(() {
      wardrobeBloc.close();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: BlocProvider<WardrobeBloc>.value(
          value: wardrobeBloc,
          child: const WardrobePage(),
        ),
      );
    }

    testWidgets(
      'WardrobePage initializes with warmup timer active, shows progress indicator and SnackBar on press',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // 1. Verificar que inicialmente durante el warm-up hay un CircularProgressIndicator
        final progressFinder = find.byType(CircularProgressIndicator);
        expect(progressFinder, findsWidgets);

        // 2. Presionar el botón de agregar prenda mientras calienta debe disparar el SnackBar
        // Buscamos el IconButton que tiene el tooltip de preparación
        final warmupButton = find.byTooltip(
          'Preparando motor de imagen... listo en 15 s',
        );
        expect(warmupButton, findsOneWidget);

        await tester.tap(warmupButton);
        await tester.pump(); // Inicia animación del SnackBar

        // Verificar texto del SnackBar
        expect(
          find.textContaining('Preparando motor de imagen... listo en'),
          findsOneWidget,
        );

        // 3. Avanzar el temporizador 15 segundos para completar el warm-up
        await tester.pump(const Duration(seconds: 16));

        // 4. Ahora debe verse el icono normal Icons.add
        expect(find.byIcon(Icons.add), findsOneWidget);
      },
    );

    testWidgets(
      'WardrobePage cancels timer safely on dispose without memory leaks',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Desmontar el widget antes de que el timer de 15s termine
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Other'))),
        );
        await tester.pump(const Duration(seconds: 1));

        // No debe haber ninguna excepción pendiente
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('WardrobePage renders RefreshIndicator for pull-to-refresh', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Desmontar el widget para cancelar el timer de 15s de WardrobePage
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('long-press selects multiple items and deletes them', (
      tester,
    ) async {
      repository.items.addAll([
        WardrobeItem(
          id: 'shirt-1',
          name: 'Camisa',
          type: 'top',
          subType: 'shirt',
          imageUrl: '',
          colors: const [],
        ),
        WardrobeItem(
          id: 'pants-1',
          name: 'Pantalón',
          type: 'bottom',
          subType: 'pants',
          imageUrl: '',
          colors: const [],
        ),
      ]);
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump();

      final cards = find.byType(WardrobeItemCard);
      expect(cards, findsNWidgets(2));
      await tester.longPress(cards.first);
      await tester.pump();
      await tester.longPress(cards.last);
      await tester.pump();
      expect(find.text('2 seleccionadas'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar seleccionadas'));
      await tester.pump();
      await tester.tap(find.text('Eliminar').last);
      await tester.pump();
      await tester.pump();
      expect(repository.deletedIds.toSet(), {'shirt-1', 'pants-1'});
    });
  });

  group('WardrobeItem Model & Reactivity Tests', () {
    test('WardrobeItem.displayImageUrl strictly prioritizes cutoutPath', () {
      final itemWithCutout = WardrobeItem(
        id: '1',
        name: 'Camisa Blanca',
        type: 'top',
        subType: 'shirt',
        imageUrl: 'https://storage.supabase.com/raw/shirt.jpg',
        cutoutPath: 'https://storage.supabase.com/cutout/shirt.webp',
        colors: const ['blanco'],
      );

      expect(
        itemWithCutout.displayImageUrl,
        'https://storage.supabase.com/cutout/shirt.webp',
      );

      final itemWithoutCutout = WardrobeItem(
        id: '2',
        name: 'Camisa Azul',
        type: 'top',
        subType: 'shirt',
        imageUrl: 'https://storage.supabase.com/raw/blue_shirt.jpg',
        cutoutPath: null,
        colors: const ['azul'],
      );

      expect(
        itemWithoutCutout.displayImageUrl,
        'https://storage.supabase.com/raw/blue_shirt.jpg',
      );
    });

    test(
      'WardrobeBloc updates in-memory item on WardrobeItemCutoutUpdated',
      () async {
        final fakeRepo = _FakeWardrobeRepository();
        final bloc = WardrobeBloc(repository: fakeRepo);

        // Esperar a que el auto-load inicial complete
        await bloc.stream.firstWhere((s) => s is WardrobeLoaded);

        // Emite estado cargado inicial con una prenda en procesamiento
        final item = WardrobeItem(
          id: 'test_item_1',
          name: 'Vestido Negro',
          type: 'one_piece',
          subType: 'dress',
          imageUrl: 'https://storage.com/raw.jpg',
          cutoutPath: null,
          processingStatus: 'processing',
          colors: const ['negro'],
        );

        bloc.emit(
          WardrobeLoaded(
            allItems: [item],
            filteredItems: [item],
            selectedCategory: 'All',
          ),
        );

        // Simula el arribo de la notificación del worker con el recorte WebP
        bloc.add(
          const WardrobeItemCutoutUpdated(
            itemId: 'test_item_1',
            cutoutPath: 'https://storage.com/cutout.webp',
            status: 'ready',
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            predicate<WardrobeState>((state) {
              if (state is WardrobeLoaded) {
                final updated = state.allItems.first;
                return updated.id == 'test_item_1' &&
                    updated.cutoutPath == 'https://storage.com/cutout.webp' &&
                    updated.processingStatus == 'ready' &&
                    !updated.isProcessing;
              }
              return false;
            }),
          ),
        );

        await bloc.close();
      },
    );
  });
}
