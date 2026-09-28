import 'package:flutter_test/flutter_test.dart';
import 'package:aifit/features/outfit/domain/outfit_models.dart';
import 'package:aifit/features/outfit/domain/saved_outfit_model.dart';
import 'package:aifit/features/outfit/data/saved_outfits_repository.dart';

void main() {
  group('Outfit UUID & 22P02 Fix Tests', () {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    test('GeneratedOutfit.ensureUuid converts "outfit_1" to a valid UUID', () {
      final uuid = GeneratedOutfit.ensureUuid('outfit_1');
      expect(uuidRegex.hasMatch(uuid), isTrue);
      expect(uuid, isNot(equals('outfit_1')));
    });

    test('GeneratedOutfit.ensureUuid preserves already-valid UUID', () {
      const validUuid = '58ad3f82-287a-44dd-96e7-752e162bc093';
      final uuid = GeneratedOutfit.ensureUuid(validUuid);
      expect(uuid, equals(validUuid));
    });

    test('GeneratedOutfit.fromJson ensures valid UUID even if API returned "outfit_1"', () {
      final json = {
        'id': 'outfit_1',
        'topId': 'top_123',
        'bottomId': 'bottom_456',
        'shoesId': 'shoes_789',
        'matchPercentage': 92,
        'explanation': 'Test explanation',
        'compatibilityScore': 0.95,
      };

      final outfit = GeneratedOutfit.fromJson(json);
      expect(uuidRegex.hasMatch(outfit.id), isTrue);
      expect(outfit.id, isNot(equals('outfit_1')));
    });

    test('SavedOutfit.fromGeneratedOutfit inherits the ensured UUID', () {
      final outfit = GeneratedOutfit(
        id: GeneratedOutfit.ensureUuid('outfit_2'),
        topId: 'top_1',
        bottomId: 'bottom_1',
        shoesId: 'shoe_1',
        matchPercentage: 90,
        explanation: 'Coordinated look',
        compatibilityScore: 0.88,
      );

      final intent = OutfitIntent(userPrompt: 'Casual summer look');
      final saved = SavedOutfit.fromGeneratedOutfit(
        outfit: outfit,
        intent: intent,
        userId: '58ad3f82-287a-44dd-96e7-752e162bc093',
        tryOnImageUrl: '',
      );

      expect(saved.id, equals(outfit.id));
      expect(uuidRegex.hasMatch(saved.id), isTrue);
    });

    test('SavedOutfitsRepository.updateTryOnImageUrl safely guards against invalid UUID without crashing', () async {
      final repo = SavedOutfitsRepository();
      // Calling with "outfit_1" should be gracefully skipped (logged) without throwing a 22P02 exception
      await expectLater(
        repo.updateTryOnImageUrl('outfit_1', 'https://example.com/tryon.jpg'),
        completes,
      );
    });
  });
}
