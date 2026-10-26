import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../data/saved_outfits_repository.dart';
import 'saved_outfits_event.dart';
import 'saved_outfits_state.dart';

/// BLoC para manejar outfits guardados
class SavedOutfitsBloc extends Bloc<SavedOutfitsEvent, SavedOutfitsState> {
  final SavedOutfitsRepository _repository = SavedOutfitsRepository();

  SavedOutfitsBloc() : super(SavedOutfitsInitial()) {
    on<LoadSavedOutfits>(_onLoadSavedOutfits);
    on<ToggleFavorite>(_onToggleFavorite);
    on<DeleteOutfit>(_onDeleteOutfit);
    on<UpdateNotes>(_onUpdateNotes);
    on<AddCustomTags>(_onAddCustomTags);
    on<ViewOutfit>(_onViewOutfit);
  }

  Future<void> _onLoadSavedOutfits(
    LoadSavedOutfits event,
    Emitter<SavedOutfitsState> emit,
  ) async {
    emit(SavedOutfitsLoading());

    try {
      final outfits = await _repository.getSavedOutfits(
        filterByOccasion: event.filterByOccasion,
        filterBySeason: event.filterBySeason,
        filterByColors: event.filterByColors,
        filterByStyleTags: event.filterByStyleTags,
        onlyFavorites: event.onlyFavorites,
      );

      final filterSummary = <String, String>{};
      if (event.filterByOccasion != null) {
        filterSummary['occasion'] = event.filterByOccasion!;
      }
      if (event.filterBySeason != null) {
        filterSummary['season'] = event.filterBySeason!;
      }
      if (event.onlyFavorites == true) {
        filterSummary['favorites'] = 'true';
      }

      emit(SavedOutfitsLoaded(
        outfits: outfits,
        filterSummary: filterSummary,
      ));
    } catch (e) {
      debugPrint('❌ Error loading saved outfits: $e');
      emit(SavedOutfitsError(message: e.toString()));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<SavedOutfitsState> emit,
  ) async {
    try {
      await _repository.toggleFavorite(event.outfitId, event.isFavorite);

      // Recargar outfits
      if (state is SavedOutfitsLoaded) {
        add(LoadSavedOutfits());
      }
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      emit(SavedOutfitsError(message: e.toString()));
    }
  }

  Future<void> _onDeleteOutfit(
    DeleteOutfit event,
    Emitter<SavedOutfitsState> emit,
  ) async {
    try {
      await _repository.deleteOutfit(event.outfitId);

      // Recargar outfits
      if (state is SavedOutfitsLoaded) {
        add(LoadSavedOutfits());
      }
    } catch (e) {
      debugPrint('❌ Error deleting outfit: $e');
      emit(SavedOutfitsError(message: e.toString()));
    }
  }

  Future<void> _onUpdateNotes(
    UpdateNotes event,
    Emitter<SavedOutfitsState> emit,
  ) async {
    try {
      await _repository.updateNotes(event.outfitId, event.notes);

      // Recargar outfits
      if (state is SavedOutfitsLoaded) {
        add(LoadSavedOutfits());
      }
    } catch (e) {
      debugPrint('❌ Error updating notes: $e');
      emit(SavedOutfitsError(message: e.toString()));
    }
  }

  Future<void> _onAddCustomTags(
    AddCustomTags event,
    Emitter<SavedOutfitsState> emit,
  ) async {
    try {
      await _repository.addCustomTags(event.outfitId, event.tags);

      // Recargar outfits
      if (state is SavedOutfitsLoaded) {
        add(LoadSavedOutfits());
      }
    } catch (e) {
      debugPrint('❌ Error adding custom tags: $e');
      emit(SavedOutfitsError(message: e.toString()));
    }
  }

  Future<void> _onViewOutfit(
    ViewOutfit event,
    Emitter<SavedOutfitsState> emit,
  ) async {
    try {
      await _repository.incrementViewCount(event.outfitId);
      // No emitir nuevo estado, solo actualizar en background
    } catch (e) {
      debugPrint('⚠️ Error incrementing view count: $e');
      // No lanzar error, es opcional
    }
  }
}
