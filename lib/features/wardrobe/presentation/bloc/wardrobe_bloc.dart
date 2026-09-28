import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/wardrobe_repository.dart';
import '../../domain/wardrobe_item_model.dart';
import 'wardrobe_event.dart';
import 'wardrobe_state.dart';

class WardrobeBloc extends Bloc<WardrobeEvent, WardrobeState> {
  final WardrobeRepository repository;
  StreamSubscription<WardrobeProcessedUpdate>? _processedSubscription;

  WardrobeBloc({required this.repository}) : super(const WardrobeInitial()) {
    on<WardrobeLoadRequested>(_onLoadRequested);
    on<LoadWardrobeItems>(
      (event, emit) => _onLoadRequested(const WardrobeLoadRequested(), emit),
    );
    on<WardrobeFilterChanged>(_onFilterChanged);
    on<WardrobeItemAdded>(_onItemAdded);
    on<WardrobeItemCutoutUpdated>(_onItemCutoutUpdated);
    on<WardrobeItemDeleted>(_onItemDeleted);
    on<WardrobeItemsDeleted>(_onItemsDeleted);

    _processedSubscription = repository.onItemProcessed.listen((update) {
      add(
        WardrobeItemCutoutUpdated(
          itemId: update.itemId,
          cutoutPath: update.cutoutPath,
          status: update.status,
        ),
      );
    });

    // Auto-load items on initialization
    add(const WardrobeLoadRequested());
  }

  Future<void> deleteItems(List<String> ids) async {
    await repository.deleteWardrobeItems(ids);
    add(const LoadWardrobeItems());
  }

  @override
  Future<void> close() {
    _processedSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadRequested(
    WardrobeLoadRequested event,
    Emitter<WardrobeState> emit,
  ) async {
    emit(const WardrobeLoading());
    try {
      final items = await repository.getWardrobeItems();
      emit(
        WardrobeLoaded(
          allItems: items,
          filteredItems: items,
          selectedCategory: 'All',
        ),
      );
    } catch (e) {
      emit(WardrobeError(e.toString()));
    }
  }

  void _onFilterChanged(
    WardrobeFilterChanged event,
    Emitter<WardrobeState> emit,
  ) {
    if (state is WardrobeLoaded) {
      final currentState = state as WardrobeLoaded;

      if (event.category == 'All') {
        emit(
          currentState.copyWith(
            selectedCategory: 'All',
            filteredItems: currentState.allItems,
          ),
        );
      } else {
        final filtered = currentState.allItems
            .where((item) => item.matchesCategory(event.category))
            .toList();
        emit(
          currentState.copyWith(
            selectedCategory: event.category,
            filteredItems: filtered,
          ),
        );
      }
    }
  }

  Future<void> _onItemAdded(
    WardrobeItemAdded event,
    Emitter<WardrobeState> emit,
  ) async {
    // Reload items from Firestore after adding a new item
    emit(const WardrobeLoading());
    try {
      final items = await repository.getWardrobeItems();

      // Preserve current filter if state was loaded
      String selectedCategory = 'All';
      if (state is WardrobeLoaded) {
        selectedCategory = (state as WardrobeLoaded).selectedCategory;
      }

      List<WardrobeItem> filteredItems = items;
      if (selectedCategory != 'All') {
        filteredItems = items
            .where((item) => item.matchesCategory(selectedCategory))
            .toList();
      }

      emit(
        WardrobeLoaded(
          allItems: items,
          filteredItems: filteredItems,
          selectedCategory: selectedCategory,
        ),
      );
    } catch (e) {
      emit(WardrobeError(e.toString()));
    }
  }

  void _onItemCutoutUpdated(
    WardrobeItemCutoutUpdated event,
    Emitter<WardrobeState> emit,
  ) {
    if (state is WardrobeLoaded) {
      final current = state as WardrobeLoaded;

      final updatedAll = current.allItems.map((item) {
        if (item.id == event.itemId) {
          return item.copyWith(
            cutoutPath:
                (event.cutoutPath != null && event.cutoutPath!.isNotEmpty)
                ? event.cutoutPath
                : item.cutoutPath,
            processingStatus: event.status,
          );
        }
        return item;
      }).toList();

      final updatedFiltered = current.filteredItems.map((item) {
        if (item.id == event.itemId) {
          return item.copyWith(
            cutoutPath:
                (event.cutoutPath != null && event.cutoutPath!.isNotEmpty)
                ? event.cutoutPath
                : item.cutoutPath,
            processingStatus: event.status,
          );
        }
        return item;
      }).toList();

      emit(
        current.copyWith(allItems: updatedAll, filteredItems: updatedFiltered),
      );
    }
  }

  Future<void> _onItemDeleted(
    WardrobeItemDeleted event,
    Emitter<WardrobeState> emit,
  ) async {
    await _onItemsDeleted(WardrobeItemsDeleted([event.itemId]), emit);
  }

  Future<void> _onItemsDeleted(
    WardrobeItemsDeleted event,
    Emitter<WardrobeState> emit,
  ) async {
    if (state is! WardrobeLoaded) return;
    final current = state as WardrobeLoaded;

    final remainingAll = current.allItems
        .where((item) => !event.itemIds.contains(item.id))
        .toList();
    final remainingFiltered = current.filteredItems
        .where((item) => !event.itemIds.contains(item.id))
        .toList();

    emit(
      current.copyWith(
        allItems: remainingAll,
        filteredItems: remainingFiltered,
      ),
    );

    try {
      await repository.deleteWardrobeItems(event.itemIds);
    } catch (e) {
      add(const LoadWardrobeItems());
    }
  }
}
