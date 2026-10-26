/// Eventos para el BLoC de outfits guardados
abstract class SavedOutfitsEvent {}

/// Cargar outfits guardados
class LoadSavedOutfits extends SavedOutfitsEvent {
  final String? filterByOccasion;
  final String? filterBySeason;
  final List<String>? filterByColors;
  final List<String>? filterByStyleTags;
  final bool? onlyFavorites;

  LoadSavedOutfits({
    this.filterByOccasion,
    this.filterBySeason,
    this.filterByColors,
    this.filterByStyleTags,
    this.onlyFavorites,
  });
}

/// Toggle favorito
class ToggleFavorite extends SavedOutfitsEvent {
  final String outfitId;
  final bool isFavorite;

  ToggleFavorite({required this.outfitId, required this.isFavorite});
}

/// Eliminar outfit
class DeleteOutfit extends SavedOutfitsEvent {
  final String outfitId;

  DeleteOutfit({required this.outfitId});
}

/// Actualizar notas
class UpdateNotes extends SavedOutfitsEvent {
  final String outfitId;
  final String? notes;

  UpdateNotes({required this.outfitId, this.notes});
}

/// Agregar tags personalizados
class AddCustomTags extends SavedOutfitsEvent {
  final String outfitId;
  final List<String> tags;

  AddCustomTags({required this.outfitId, required this.tags});
}

/// Ver outfit (incrementa view count)
class ViewOutfit extends SavedOutfitsEvent {
  final String outfitId;

  ViewOutfit({required this.outfitId});
}
