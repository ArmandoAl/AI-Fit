import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/interfaces/ai_service.dart';
import '../../../core/platform/app_image.dart';
import '../../../core/services/apple_vision_background_removal_service.dart';
import '../../../core/services/deepseek_service.dart';
import '../../../core/services/gateway_ai_service_impl.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_client.dart';
import '../domain/wardrobe_ai_metadata.dart';
import '../domain/wardrobe_analysis_prompt.dart';
import '../domain/wardrobe_item_model.dart';
import 'wardrobe_repository.dart';

class WardrobeRepositoryImpl implements WardrobeRepository {
  final AIService _aiService;
  final DeepSeekService _gateway;
  final StorageService _storageService = StorageService();

  WardrobeRepositoryImpl({AIService? aiService, DeepSeekService? gateway})
      : _aiService = aiService ?? GatewayAIServiceImpl(),
        _gateway = gateway ?? const DeepSeekService();

  SupabaseClient get _supabase {
    final client = AppSupabaseClient.client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  String? _getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Genera el cutout on-device con Apple Vision (iOS-only). Retorna `null` en cualquier
  /// otra plataforma o si Vision no detecta un objeto en foreground; en ese caso el item
  /// se procesa sin cutout, sin bloquear el flujo de alta de la prenda.
  Future<String?> _generateCutoutBase64(AppImage image) async {
    try {
      final cutoutBytes = await AppleVisionBackgroundRemovalService.removeBackground(image.bytes);
      if (cutoutBytes == null) return null;
      debugPrint('✅ [WardrobeRepository] Apple Vision cutout generado on-device (${cutoutBytes.length} bytes)');
      return base64Encode(cutoutBytes);
    } catch (e) {
      debugPrint('⚠️ [WardrobeRepository] Apple Vision cutout failed (non-critical): $e');
      return null;
    }
  }

  @override
  Future<List<WardrobeItem>> getWardrobeItems() async {
    final uid = _getCurrentUserId();
    if (uid == null) {
      debugPrint('⚠️ No user logged in, returning empty wardrobe');
      return [];
    }

    try {
      debugPrint('📦 [WardrobeRepository -> Supabase] Loading items for user: $uid');
      final response = await _supabase
          .from('wardrobe_items')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final items = (response as List)
          .map((row) =>
              WardrobeItem.fromSupabase(Map<String, dynamic>.from(row as Map)))
          .toList();

      debugPrint('✅ [WardrobeRepository -> Supabase] Loaded ${items.length} wardrobe items');
      return items;
    } catch (e) {
      debugPrint('❌ [WardrobeRepository -> Supabase] Error loading items: $e');
      return [];
    }
  }

  Future<void> addWardrobeItem(AppImage image) async {
    final uid = _getCurrentUserId();
    if (uid == null) throw Exception("User not logged in");

    // 1. Upload image to Storage (bucket 'user-media')
    final imageUrl = await _storageService.uploadWardrobeItem(
      userId: uid,
      image: image,
    );

    final aiData = await _aiService.analyzeImageToJson(
      image: image,
      promptInstruction: WardrobeAnalysisPrompt.fullAnalysis,
    );

    final fields = wardrobeFieldsFromAiJson(aiData);
    final itemId = const Uuid().v4();
    final category = (fields['type'] ?? fields['category'] ?? 'top').toString();

    await _supabase.from('wardrobe_items').insert({
      'id': itemId,
      'user_id': uid,
      'name': fields['name'] ?? fields['subType'] ?? 'Prenda',
      'category': category,
      'subtype': fields['subType'] ?? fields['name'] ?? 'item',
      'source_path': imageUrl,
      'content_hash': 'hash_${itemId}_${DateTime.now().millisecondsSinceEpoch}',
      'colors': fields['colors'] ?? [],
      'style_tags': fields['styleTags'] ?? [],
      'seasons': fields['season'] ?? [],
      'ai_metadata': aiData,
      'processing_status': 'processing',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    debugPrint('✅ [WardrobeRepository -> Supabase] Item added: $itemId');

    // Cutout on-device (Apple Vision, iOS-only) + extracción de embedding CLIP (clip-ViT-B-32) en el worker.
    // Se utiliza timeout acotado de 12s para no bloquear la app si el worker se encuentra ocupado
    try {
      final cutoutBase64 = await _generateCutoutBase64(image);
      debugPrint('✂️ [WardrobeRepository] Invoking image-worker (CLIP ViT-B-32) for item: $itemId');
      final processResult = await _gateway.processWardrobeItem(
        itemId: itemId,
        userId: uid,
        imagePath: imageUrl,
        cutoutBase64: cutoutBase64,
        timeout: const Duration(seconds: 12),
        maxRetries: 1,
      );
      debugPrint('✅ [WardrobeRepository] image-worker processing completed: $processResult');
    } catch (workerErr) {
      debugPrint('⚠️ [WardrobeRepository] image-worker processing error or timeout (raw item preserved as fallback): $workerErr');
      // Heurística: visibilidad del estado del sistema — sin esto el item quedaba
      // en 'processing' para siempre si la llamada nunca llegó a completarse en el worker.
      await _markProcessingFailed(itemId, workerErr.toString());
    }
  }

  Future<void> addWardrobeItemWithData({
    required AppImage image,
    required String type,
    required String subType,
    String? brand,
  }) async {
    final uid = _getCurrentUserId();
    if (uid == null) throw Exception("User not logged in");

    debugPrint('📦 Adding wardrobe item:');
    debugPrint('   - User ID: $uid');
    debugPrint('   - Type: $type');
    debugPrint('   - SubType: $subType');
    debugPrint('   - Brand: ${brand ?? "none"}');

    // 1. Upload image to Storage
    final imageUrl = await _storageService.uploadWardrobeItem(
      userId: uid,
      image: image,
    );

    List<String> colors = [];
    List<String> styleTags = [];
    Map<String, dynamic> aiData = {};

    try {
      aiData = await _aiService.analyzeImageToJson(
        image: image,
        promptInstruction: WardrobeAnalysisPrompt.colorsAndStyleOnly,
      );

      colors = (aiData['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      styleTags = (aiData['styleTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
    } catch (e) {
      debugPrint('⚠️ AI analysis failed (non-critical): $e');
    }

    final itemId = const Uuid().v4();
    await _supabase.from('wardrobe_items').insert({
      'id': itemId,
      'user_id': uid,
      'name': subType,
      'category': type,
      'subtype': subType,
      'brand': (brand != null && brand.isNotEmpty) ? brand : null,
      'source_path': imageUrl,
      'content_hash': 'hash_${itemId}_${DateTime.now().millisecondsSinceEpoch}',
      'colors': colors,
      'style_tags': styleTags,
      'seasons': [],
      'ai_metadata': aiData,
      'processing_status': 'processing',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    debugPrint('✅ [WardrobeRepository -> Supabase] Item with data added: $itemId');

    // Cutout on-device (Apple Vision, iOS-only) + extracción de embedding CLIP (clip-ViT-B-32) en el worker.
    // Se utiliza timeout acotado de 12s para no bloquear la app si el worker se encuentra ocupado
    try {
      final cutoutBase64 = await _generateCutoutBase64(image);
      debugPrint('✂️ [WardrobeRepository] Invoking image-worker (CLIP ViT-B-32) for item: $itemId');
      final processResult = await _gateway.processWardrobeItem(
        itemId: itemId,
        userId: uid,
        imagePath: imageUrl,
        cutoutBase64: cutoutBase64,
        timeout: const Duration(seconds: 12),
        maxRetries: 1,
      );
      debugPrint('✅ [WardrobeRepository] image-worker processing completed: $processResult');
    } catch (workerErr) {
      debugPrint('⚠️ [WardrobeRepository] image-worker processing error or timeout (raw item preserved as fallback): $workerErr');
      // Heurística: visibilidad del estado del sistema — sin esto el item quedaba
      // en 'processing' para siempre si la llamada nunca llegó a completarse en el worker.
      await _markProcessingFailed(itemId, workerErr.toString());
    }
  }

  @override
  Future<void> retryProcessing(WardrobeItem item) async {
    final uid = _getCurrentUserId();
    if (uid == null) throw Exception("User not logged in");

    try {
      await _supabase
          .from('wardrobe_items')
          .update({'processing_status': 'processing', 'processing_error': null})
          .eq('id', item.id);

      final processResult = await _gateway.processWardrobeItem(
        itemId: item.id,
        userId: uid,
        imagePath: item.imageUrl,
        timeout: const Duration(seconds: 12),
        maxRetries: 1,
      );
      debugPrint('✅ [WardrobeRepository] Retry succeeded for ${item.id}: $processResult');
    } catch (e) {
      debugPrint('❌ [WardrobeRepository] Retry failed for ${item.id}: $e');
      await _markProcessingFailed(item.id, e.toString());
      rethrow;
    }
  }

  Future<void> _markProcessingFailed(String itemId, String error) async {
    try {
      await _supabase
          .from('wardrobe_items')
          .update({'processing_status': 'failed', 'processing_error': error})
          .eq('id', itemId);
    } catch (e) {
      debugPrint('⚠️ [WardrobeRepository] Could not mark item $itemId as failed: $e');
    }
  }

  @override
  Future<void> updateWardrobeItem(WardrobeItem item) async {
    final uid = _getCurrentUserId();
    if (uid == null) throw Exception("User not logged in");

    debugPrint('📝 Updating wardrobe item: ${item.id}');

    try {
      await _supabase
          .from('wardrobe_items')
          .update(item.toSupabase(userId: uid))
          .eq('id', item.id);
      debugPrint('✅ [WardrobeRepository -> Supabase] Item updated');
    } catch (e) {
      debugPrint('❌ [WardrobeRepository -> Supabase] Error updating item: $e');
      throw Exception('Failed to update wardrobe item: $e');
    }
  }
}
