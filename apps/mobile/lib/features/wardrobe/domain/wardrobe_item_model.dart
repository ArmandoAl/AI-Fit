import 'wardrobe_ai_metadata.dart';

class WardrobeItem {
  static const List<String> validCategories = [
    'top',
    'bottom',
    'one_piece',
    'shoes',
    'outerwear',
    'accessories',
  ];

  static const Map<String, List<String>> commonSubtypes = {
    'top': ['t-shirt', 'shirt', 'sweater', 'hoodie', 'tank-top', 'blouse'],
    'bottom': ['jeans', 'pants', 'shorts', 'skirt', 'chinos', 'sweatpants'],
    'one_piece': ['dress', 'jumpsuit', 'romper', 'vestido', 'enterizo'],
    'shoes': ['sneakers', 'boots', 'sandals', 'dress-shoes', 'sports-shoes'],
    'outerwear': ['jacket', 'coat', 'blazer', 'cardigan', 'vest'],
    'accessories': [
      'scarf',
      'earrings',
      'necklace',
      'bag',
      'belt',
      'bufanda',
      'aretes',
      'collar',
      'bolso',
    ],
  };

  static String normalizeCategory(String raw) {
    final clean = raw.trim().toLowerCase().replaceAll('-', '_');
    if (clean == 'one_piece' ||
        clean == 'dress' ||
        clean == 'vestido' ||
        clean == 'jumpsuit' ||
        clean == 'enterizo' ||
        clean == 'romper') {
      return 'one_piece';
    }
    if (clean == 'accessories' ||
        clean == 'accessory' ||
        clean == 'accesorio' ||
        clean == 'accesorios') {
      return 'accessories';
    }
    return clean;
  }

  final String id;
  final String name;
  final String
  type; // 'top', 'bottom', 'one_piece', 'shoes', 'outerwear', 'accessories'
  final String subType; // e.g., 'jeans', 't-shirt', 'sweater', 'dress', 'scarf'
  final String imageUrl;
  final String?
  cutoutPath; // Tarea 3.2 & 3.4: WebP cutout transparente en Supabase Storage
  final List<String> colors; // Array of colors
  final String? brand; // Optional
  final List<String> styleTags; // e.g., ['casual', 'formal']
  final List<String> season; // e.g., ['spring', 'summer']
  final DateTime? createdAt;
  final WardrobeAiMetadata? aiMetadata;

  /// 'processing' | 'ready' | 'failed'. Heurística: visibilidad del estado
  /// del sistema — permite mostrar en la UI que una prenda aún no tiene
  /// cutout/embedding, o que su procesamiento falló.
  final String? processingStatus;

  bool get isProcessing => processingStatus == 'processing';
  bool get processingFailed => processingStatus == 'failed';
  String? get sourcePath => imageUrl;

  WardrobeItem({
    required this.id,
    required this.name,
    required this.type,
    required this.subType,
    required this.imageUrl,
    required this.colors,
    this.cutoutPath,
    this.brand,
    this.styleTags = const [],
    this.season = const [],
    this.createdAt,
    this.aiMetadata,
    this.processingStatus,
  });

  // Legacy: category maps to type for backward compatibility
  String get category => type;

  /// URL de visualización para catálogo: prioriza la prenda recortada sobre fondo transparente/blanco
  String get displayImageUrl {
    final cutout = cutoutPath?.trim();
    if (cutout != null && cutout.isNotEmpty) {
      return cutout;
    }
    return imageUrl;
  }

  bool get isOnePiece =>
      type == 'one_piece' ||
      type == 'one-piece' ||
      type == 'dress' ||
      type == 'vestido';

  bool get isAccessory =>
      type == 'accessories' ||
      type == 'accessory' ||
      type == 'accesorio' ||
      type == 'accesorios';

  bool get isTop => type == 'top';
  bool get isBottom => type == 'bottom';
  bool get isShoes => type == 'shoes';
  bool get isOuterwear => type == 'outerwear';

  bool matchesCategory(String filterCategory) {
    if (filterCategory.toLowerCase() == 'all') return true;
    final target = normalizeCategory(filterCategory);
    final current = normalizeCategory(type);
    return target == current;
  }

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    final aiMetadata = WardrobeAiMetadata.fromJson(json);
    final rawType = (json['type'] ?? json['category'] ?? 'unknown').toString();

    return WardrobeItem(
      id: json['id'] ?? json['documentId'] ?? '',
      name: json['name'] ?? json['subType'] ?? 'Unknown',
      type: normalizeCategory(rawType),
      subType: json['subType'] ?? json['name'] ?? 'unknown',
      imageUrl: json['imageUrl'] ?? '',
      cutoutPath: json['cutoutPath'] ?? json['cutout_path'],
      colors: json['colors'] != null
          ? List<String>.from(json['colors'])
          : (json['color'] != null ? [json['color'].toString()] : []),
      brand: json['brand'],
      styleTags: json['styleTags'] != null
          ? List<String>.from(json['styleTags'])
          : [],
      season: json['season'] != null ? List<String>.from(json['season']) : [],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
                ? json['createdAt'] as DateTime
                : DateTime.tryParse(json['createdAt'].toString()))
          : null,
      aiMetadata: aiMetadata.isEmpty ? null : aiMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'subType': subType,
      'imageUrl': imageUrl,
      if (cutoutPath != null) 'cutoutPath': cutoutPath,
      'colors': colors,
      if (brand != null) 'brand': brand,
      'styleTags': styleTags,
      'season': season,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      ...?aiMetadata?.toJson().isEmpty == false ? aiMetadata!.toJson() : null,
    };
  }

  factory WardrobeItem.fromSupabase(Map<String, dynamic> json) {
    WardrobeAiMetadata? metadata;
    if (json['ai_metadata'] != null && json['ai_metadata'] is Map) {
      metadata = WardrobeAiMetadata.fromJson(
        Map<String, dynamic>.from(json['ai_metadata'] as Map),
      );
    }

    final rawCategory = (json['category'] ?? json['type'] ?? 'top').toString();

    return WardrobeItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['subtype'] ?? 'Unknown',
      type: normalizeCategory(rawCategory),
      subType: json['subtype'] ?? json['name'] ?? 'unknown',
      imageUrl: json['source_path'] ?? '',
      cutoutPath: json['cutout_path'] as String?,
      colors: json['colors'] != null
          ? List<String>.from(json['colors'] as List)
          : [],
      brand: json['brand'] as String?,
      styleTags: json['style_tags'] != null
          ? List<String>.from(json['style_tags'] as List)
          : [],
      season: json['seasons'] != null
          ? List<String>.from(json['seasons'] as List)
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      aiMetadata: (metadata == null || metadata.isEmpty) ? null : metadata,
      processingStatus: json['processing_status'] as String?,
    );
  }

  Map<String, dynamic> toSupabase({required String userId}) {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
      'category': normalizeCategory(type),
      'subtype': subType,
      'source_path': imageUrl,
      if (cutoutPath != null) 'cutout_path': cutoutPath,
      'content_hash':
          'hash_${id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch}',
      'colors': colors,
      'style_tags': styleTags,
      'seasons': season,
      if (brand != null) 'brand': brand,
      'ai_metadata': (aiMetadata != null && !aiMetadata!.isEmpty)
          ? aiMetadata!.toJson()
          : {},
      'processing_status': 'ready',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  WardrobeItem copyWith({
    String? id,
    String? name,
    String? type,
    String? subType,
    String? imageUrl,
    String? cutoutPath,
    List<String>? colors,
    String? brand,
    List<String>? styleTags,
    List<String>? season,
    DateTime? createdAt,
    WardrobeAiMetadata? aiMetadata,
    bool clearAiMetadata = false,
    String? processingStatus,
  }) {
    return WardrobeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      subType: subType ?? this.subType,
      imageUrl: imageUrl ?? this.imageUrl,
      cutoutPath: cutoutPath ?? this.cutoutPath,
      colors: colors ?? this.colors,
      brand: brand ?? this.brand,
      styleTags: styleTags ?? this.styleTags,
      season: season ?? this.season,
      createdAt: createdAt ?? this.createdAt,
      aiMetadata: clearAiMetadata ? null : (aiMetadata ?? this.aiMetadata),
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }

  @override
  String toString() {
    return 'WardrobeItem(id: $id, name: $name, type: $type, subType: $subType, imageUrl: $imageUrl, cutoutPath: $cutoutPath, colors: $colors, brand: $brand)';
  }
}
