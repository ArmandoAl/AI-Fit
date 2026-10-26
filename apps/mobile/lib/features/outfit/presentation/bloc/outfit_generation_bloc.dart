import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/outfit_models.dart';
import '../../domain/try_on_status.dart';
import '../../services/outfit_service.dart';
import 'outfit_generation_event.dart';
import 'outfit_generation_state.dart';

/// BLoC con flujo progresivo P1: outfits primero, try-on bajo demanda.
class OutfitGenerationBloc
    extends Bloc<OutfitGenerationEvent, OutfitGenerationState> {
  final OutfitService _outfitService;

  OutfitGenerationBloc({OutfitService? outfitService})
      : _outfitService = outfitService ?? OutfitService(),
        super(OutfitGenerationInitial()) {
    on<GenerateOutfitsRequested>(_onGenerateOutfitsRequested);
    on<GenerateTryOnImageRequested>(_onGenerateTryOnImageRequested);
    on<OutfitGenerationReset>(_onReset);
  }

  Future<void> _onGenerateOutfitsRequested(
    GenerateOutfitsRequested event,
    Emitter<OutfitGenerationState> emit,
  ) async {
    try {
      emit(OutfitGenerationLoading(currentPhase: 'analyzing'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      emit(OutfitGenerationLoading(currentPhase: 'filtering'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      emit(OutfitGenerationLoading(currentPhase: 'generating'));

      final result = await _outfitService.generateOutfitSuggestions(
        userPrompt: event.userPrompt,
      );

      final statuses = <String, TryOnStatus>{};
      for (var i = 0; i < result.outfits.length; i++) {
        final id = result.outfits[i].id;
        if (!event.generateImage) {
          statuses[id] = TryOnStatus.none;
        } else {
          statuses[id] = TryOnStatus.generating;
        }
      }

      var loaded = OutfitGenerationLoaded(
        outfits: result.outfits,
        intent: result.intent,
        tryOnStatuses: statuses,
        wardrobeImageUrlsByItemId: result.wardrobeImageUrlsByItemId,
      );

      emit(loaded);

      if (!event.generateImage || result.outfits.isEmpty) {
        return;
      }

      for (final outfit in result.outfits) {
        await _runTryOnForOutfit(
          outfitId: outfit.id,
          emit: emit,
          loaded: state is OutfitGenerationLoaded
              ? state as OutfitGenerationLoaded
              : loaded,
        );
      }
    } catch (e) {
      debugPrint('❌ Error generating outfits: $e');
      emit(OutfitGenerationError(message: e.toString()));
    }
  }

  Future<void> _onGenerateTryOnImageRequested(
    GenerateTryOnImageRequested event,
    Emitter<OutfitGenerationState> emit,
  ) async {
    final current = state;
    if (current is! OutfitGenerationLoaded) return;

    final status = current.statusFor(event.outfitId);
    if (status == TryOnStatus.generating || status == TryOnStatus.ready) {
      return;
    }

    await _runTryOnForOutfit(
      outfitId: event.outfitId,
      emit: emit,
      loaded: current,
    );
  }

  Future<void> _runTryOnForOutfit({
    required String outfitId,
    required Emitter<OutfitGenerationState> emit,
    required OutfitGenerationLoaded loaded,
  }) async {
    GeneratedOutfit? outfit;
    for (final o in loaded.outfits) {
      if (o.id == outfitId) {
        outfit = o;
        break;
      }
    }
    if (outfit == null) return;

    final statuses = Map<String, TryOnStatus>.from(loaded.tryOnStatuses);
    final errors = Map<String, String>.from(loaded.tryOnErrors);
    statuses[outfitId] = TryOnStatus.generating;
    errors.remove(outfitId);

    loaded = loaded.copyWith(
      tryOnStatuses: statuses,
      tryOnErrors: errors,
    );
    emit(loaded);

    try {
      final url = await _outfitService.generateTryOnForOutfit(
        outfit: outfit,
        intent: loaded.intent,
        tryOnProvider: tryOnProviderForPosition(loaded.outfits.indexOf(outfit)),
        wardrobeImageUrlsByItemId: loaded.wardrobeImageUrlsByItemId,
      );

      final latest = state;
      if (latest is! OutfitGenerationLoaded) return;

      statuses.addAll(latest.tryOnStatuses);
      errors.addAll(latest.tryOnErrors);
      final urls = Map<String, String>.from(latest.tryOnImageUrls);

      if (url != null && url.isNotEmpty) {
        urls[outfitId] = url;
        statuses[outfitId] = TryOnStatus.ready;
        errors.remove(outfitId);

        emit(
          latest.copyWith(
            tryOnImageUrls: urls,
            tryOnStatuses: statuses,
            tryOnImageUrl: latest.tryOnImageUrl ?? url,
          ),
        );
      } else {
        statuses[outfitId] = TryOnStatus.failed;
        errors[outfitId] = 'No se pudo generar la imagen';
        emit(latest.copyWith(tryOnStatuses: statuses, tryOnErrors: errors));
      }
    } catch (e) {
      final latest = state;
      if (latest is! OutfitGenerationLoaded) return;

      statuses.addAll(latest.tryOnStatuses);
      errors.addAll(latest.tryOnErrors);
      statuses[outfitId] = TryOnStatus.failed;
      errors[outfitId] = e.toString();

      emit(latest.copyWith(tryOnStatuses: statuses, tryOnErrors: errors));
    }
  }

  void _onReset(
    OutfitGenerationReset event,
    Emitter<OutfitGenerationState> emit,
  ) {
    emit(OutfitGenerationInitial());
  }
}
