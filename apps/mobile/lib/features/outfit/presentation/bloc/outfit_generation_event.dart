// Eventos para el BLoC de generación de outfits

abstract class OutfitGenerationEvent {}

/// Solicita generar outfits basado en un prompt del usuario
class GenerateOutfitsRequested extends OutfitGenerationEvent {
  final String userPrompt;
  final bool generateImage;

  GenerateOutfitsRequested({
    required this.userPrompt,
    this.generateImage = false,
  });
}

/// Solicita generar imagen de Virtual Try-On para un outfit específico
class GenerateTryOnImageRequested extends OutfitGenerationEvent {
  final String outfitId;

  GenerateTryOnImageRequested({required this.outfitId});
}

/// Resetea el estado a inicial
class OutfitGenerationReset extends OutfitGenerationEvent {}
