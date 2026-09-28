import 'package:equatable/equatable.dart';
import '../../domain/wardrobe_item_model.dart';

abstract class WardrobeState extends Equatable {
  const WardrobeState();

  List<WardrobeItem> get allItems => const [];
  List<WardrobeItem> get items => allItems;

  @override
  List<Object?> get props => [];
}

class WardrobeInitial extends WardrobeState {
  const WardrobeInitial();
}

class WardrobeLoading extends WardrobeState {
  const WardrobeLoading();
}

class WardrobeLoaded extends WardrobeState {
  @override
  final List<WardrobeItem> allItems;
  final List<WardrobeItem> filteredItems;
  final String selectedCategory;

  const WardrobeLoaded({
    required this.allItems,
    required this.filteredItems,
    this.selectedCategory = 'All',
  });

  WardrobeLoaded copyWith({
    List<WardrobeItem>? allItems,
    List<WardrobeItem>? filteredItems,
    String? selectedCategory,
  }) {
    return WardrobeLoaded(
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  @override
  List<Object?> get props => [allItems, filteredItems, selectedCategory];
}

class WardrobeError extends WardrobeState {
  final String message;

  const WardrobeError(this.message);

  @override
  List<Object?> get props => [message];
}
