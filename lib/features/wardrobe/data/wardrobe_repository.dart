import '../domain/wardrobe_item_model.dart';

class WardrobeProcessedUpdate {
  final String itemId;
  final String? cutoutPath;
  final String status;

  const WardrobeProcessedUpdate({
    required this.itemId,
    this.cutoutPath,
    this.status = 'ready',
  });
}

/// Abstract repository interface for wardrobe items
abstract class WardrobeRepository {
  /// Get all wardrobe items for the current authenticated user
  Future<List<WardrobeItem>> getWardrobeItems();

  /// Update a wardrobe item
  Future<void> updateWardrobeItem(WardrobeItem item);

  /// Reintenta el procesamiento (cutout + embedding CLIP) de un item existente
  /// cuyo processing_status quedó en 'failed' o 'processing' indefinidamente.
  Future<void> retryProcessing(WardrobeItem item);

  Future<void> deleteWardrobeItems(List<String> ids);

  Future<void> deleteWardrobeItem(String id);

  Stream<WardrobeProcessedUpdate> get onItemProcessed;
}
