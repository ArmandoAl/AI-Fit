import 'package:equatable/equatable.dart';

abstract class WardrobeEvent extends Equatable {
  const WardrobeEvent();

  @override
  List<Object?> get props => [];
}

class WardrobeLoadRequested extends WardrobeEvent {
  const WardrobeLoadRequested();
}

class WardrobeFilterChanged extends WardrobeEvent {
  final String category;

  const WardrobeFilterChanged(this.category);

  @override
  List<Object?> get props => [category];
}

class WardrobeItemAdded extends WardrobeEvent {
  const WardrobeItemAdded();
}

/// Evento para refrescar la lista de prendas (usado por RefreshIndicator)
class LoadWardrobeItems extends WardrobeEvent {
  const LoadWardrobeItems();
}

/// Evento reactivo para actualizar el cutout y estado de una prenda en memoria
class WardrobeItemCutoutUpdated extends WardrobeEvent {
  final String itemId;
  final String? cutoutPath;
  final String status;

  const WardrobeItemCutoutUpdated({
    required this.itemId,
    this.cutoutPath,
    this.status = 'ready',
  });

  @override
  List<Object?> get props => [itemId, cutoutPath, status];
}

/// Evento para eliminar una sola prenda
class WardrobeItemDeleted extends WardrobeEvent {
  final String itemId;

  const WardrobeItemDeleted(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

/// Evento para eliminar múltiples prendas seleccionadas
class WardrobeItemsDeleted extends WardrobeEvent {
  final List<String> itemIds;

  const WardrobeItemsDeleted(this.itemIds);

  @override
  List<Object?> get props => [itemIds];
}
