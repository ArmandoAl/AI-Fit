import 'package:aifit/features/outfit/domain/saved_outfit_model.dart';

/// Estados para el BLoC de outfits guardados
abstract class SavedOutfitsState {}

/// Estado inicial
class SavedOutfitsInitial extends SavedOutfitsState {}

/// Cargando
class SavedOutfitsLoading extends SavedOutfitsState {}

/// Outfits cargados
class SavedOutfitsLoaded extends SavedOutfitsState {
  final List<SavedOutfit> outfits;
  final Map<String, String> filterSummary; // Resumen de filtros aplicados

  SavedOutfitsLoaded({
    required this.outfits,
    Map<String, String>? filterSummary,
  }) : filterSummary = filterSummary ?? {};

  int get totalCount => outfits.length;
  int get favoritesCount => outfits.where((o) => o.isFavorite).length;
}

/// Error
class SavedOutfitsError extends SavedOutfitsState {
  final String message;

  SavedOutfitsError({required this.message});
}
