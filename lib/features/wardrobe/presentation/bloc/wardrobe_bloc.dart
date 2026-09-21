import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/wardrobe_repository.dart';
import '../../domain/wardrobe_item_model.dart';
import 'wardrobe_event.dart';
import 'wardrobe_state.dart';

class WardrobeBloc extends Bloc<WardrobeEvent, WardrobeState> {
  final WardrobeRepository repository;

  WardrobeBloc({required this.repository}) : super(const WardrobeInitial()) {
    on<WardrobeLoadRequested>(_onLoadRequested);
    on<WardrobeFilterChanged>(_onFilterChanged);
    on<WardrobeItemAdded>(_onItemAdded);

    // Auto-load items on initialization
    add(const WardrobeLoadRequested());
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
            .where(
              (item) => item.matchesCategory(event.category),
            )
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
            .where(
              (item) => item.matchesCategory(selectedCategory),
            )
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
}
