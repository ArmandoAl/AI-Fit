import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interfaces/ai_service.dart';
import '../../../core/platform/app_image.dart';
import '../../../core/platform/network_image_loader.dart';
import '../../../core/services/gateway_ai_service_impl.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/utils/identity_photo_collage.dart';
import '../../../core/utils/image_compression_util.dart';
import '../domain/user_identity_profile.dart';

class UserIdentityAnalysisService {
  final AIService _aiService;
  final StorageService _storageService;
  final Dio _dio;

  UserIdentityAnalysisService({
    AIService? aiService,
    StorageService? storageService,
    Dio? dio,
  })  : _aiService = aiService ?? GatewayAIServiceImpl(),
        _storageService = storageService ?? StorageService(),
        _dio = dio ?? Dio();

  SupabaseClient get _supabase {
    final client = AppSupabaseClient.client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  static const _identityAnalysisPrompt = '''
You are a professional biometric and body-proportion analyst for fashion virtual try-on.

Analyze the attached identity reference collage (4 rows: front face, 3/4 face, full body front, full body side).

Return ONLY valid JSON with this structure (snake_case, all fields optional but fill what you can infer):
{
  "identity_version": 1,
  "skin_tone": { "primary": "...", "undertone": "...", "confidence": 0.0-1.0 },
  "face": { "shape": "...", "jaw_definition": "...", "eye_shape": "...", "nose_shape": "..." },
  "hair": { "color": "...", "style": "...", "density": "..." },
  "body": { "type": "...", "height_estimate": "...", "shoulder_width": "...", "build": "...", "proportions": "..." },
  "visual_characteristics": { "contrast_level": "...", "facial_sharpness": "...", "overall_presence": "..." }
}

Rules: concise, deterministic, infer ethnicity consistency from visible features without stereotyping labels in output.
''';

  Future<IdentityProfile?> analyzeUserIdentity({
    required String userId,
    List<String> facePhotoUrls = const [],
    List<String> bodyPhotoUrls = const [],
  }) async {
    final validFace = _filterUrls(facePhotoUrls);
    final validBody = _filterUrls(bodyPhotoUrls);
    if (validFace.isEmpty && validBody.isEmpty) return null;

    try {
      final faceBytes = await _downloadPhotoBytes(validFace);
      final bodyBytes = await _downloadPhotoBytes(validBody);

      if (faceBytes.isEmpty && bodyBytes.isEmpty) return null;

      final collageBytes = await IdentityPhotoCollage.buildVertical(
        facePhotos: faceBytes,
        bodyPhotos: bodyBytes,
      );

      final collageUrl = await _uploadCollage(userId, collageBytes);

      final raw = await _aiService.analyzeImageToJson(
        image: AppImage(bytes: collageBytes, name: 'collage.jpg'),
        promptInstruction: _identityAnalysisPrompt,
        imagePayload: AiImagePayload.identity,
      );
      final profile = IdentityProfile.fromJson(raw);

      if (profile.isEmpty) {
        debugPrint('⚠️ Identity analysis returned empty profile');
        return null;
      }

      await _supabase.from('profiles').update({
        'identity_profile': profile.toJson(),
        'identity_version':
            profile.identityVersion ?? IdentityProfile.currentVersion,
        'identity_collage_path': collageUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ Identity profile v${profile.identityVersion} saved to Supabase');
      return profile;
    } catch (e) {
      debugPrint('❌ analyzeUserIdentity failed: $e');
      return null;
    }
  }

  Future<void> analyzeAndSaveProfiles({
    required String userId,
    List<String> facePhotoUrls = const [],
    List<String> bodyPhotoUrls = const [],
  }) async {
    await analyzeUserIdentity(
      userId: userId,
      facePhotoUrls: facePhotoUrls,
      bodyPhotoUrls: bodyPhotoUrls,
    );
  }

  List<String> _filterUrls(List<String> urls) {
    return urls.where((u) => u.isNotEmpty && !u.startsWith('mock://')).toList();
  }

  Future<List<Uint8List>> _downloadPhotoBytes(List<String> urls) async {
    final list = <Uint8List>[];
    for (var i = 0; i < urls.length && i < 4; i++) {
      try {
        list.add(await NetworkImageLoader.downloadBytes(_dio, urls[i]));
      } catch (e) {
        debugPrint('⚠️ Failed to download photo $i: $e');
      }
    }
    return list;
  }

  Future<String> _uploadCollage(String userId, Uint8List bytes) async {
    return _storageService.uploadIdentityCollage(
      userId: userId,
      bytes: bytes,
    );
  }
}
