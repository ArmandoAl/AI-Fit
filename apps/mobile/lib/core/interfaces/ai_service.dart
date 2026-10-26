import '../platform/app_image.dart';
import '../utils/image_compression_util.dart';

class AIResponse {
  final String text;
  final Map<String, dynamic>? jsonMetadata;

  AIResponse({required this.text, this.jsonMetadata});
}

abstract class AIService {
  Future<AIResponse> generateContent({
    required String prompt,
    List<AppImage>? images,
    String? modelId,
  });

  Future<Map<String, dynamic>> analyzeImageToJson({
    required AppImage image,
    required String promptInstruction,
    AiImagePayload imagePayload = AiImagePayload.garment,
  });
}
