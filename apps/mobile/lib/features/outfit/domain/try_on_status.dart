/// Estado del try-on virtual por outfit.
enum TryOnStatus {
  /// Sin preview solicitado.
  none,

  /// Outfit listo; el usuario puede generar try-on bajo demanda.
  readyForTryOn,

  /// Generando imagen en este momento.
  generating,

  /// Imagen disponible.
  ready,

  /// Falló la generación.
  failed,
}
