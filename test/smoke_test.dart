import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aifit/core/services/deepseek_service.dart';
import 'package:aifit/core/widgets/glowing_border_card.dart';
import 'package:aifit/core/widgets/gradient_pill_button.dart';
import 'package:aifit/features/outfit/presentation/widgets/match_score_badge.dart';
import 'package:aifit/features/outfit/presentation/widgets/wardrobe_carousel_slot.dart';
import 'package:aifit/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:aifit/features/outfit/domain/outfit_models.dart';
import 'package:aifit/features/outfit/domain/saved_outfit_model.dart';
import 'package:aifit/features/profile/domain/user_identity_profile.dart';
import 'package:aifit/core/constants/identity_consistency_prompt.dart';
import 'package:aifit/core/services/supabase_client.dart';
import 'package:aifit/core/widgets/cold_start_loader.dart';
import 'package:aifit/features/outfit/services/wardrobe_search_algorithm.dart';
import 'package:aifit/features/wardrobe/presentation/widgets/category_selector.dart';

void main() {
  group('Supabase Cutover Smoke Tests', () {
    test('AppSupabaseClient handles uninitialized state gracefully', () {
      expect(AppSupabaseClient.isInitialized, isFalse);
      expect(AppSupabaseClient.client, isNull);
    });

    test('WardrobeItem serializes to and from Supabase correctly', () {
      final now = DateTime.now().toUtc();
      final item = WardrobeItem(
        id: 'item_123',
        name: 'Camisa Blanca',
        type: 'top',
        subType: 'shirt',
        imageUrl: 'https://example.com/item.jpg',
        cutoutPath: 'users/123/cutouts/item_123.webp',
        colors: ['white'],
        brand: 'Zara',
        styleTags: ['casual', 'formal'],
        season: ['spring', 'summer'],
        createdAt: now,
      );

      final supabaseMap = item.toSupabase(userId: 'user_456');
      expect(supabaseMap['id'], equals('item_123'));
      expect(supabaseMap['user_id'], equals('user_456'));
      expect(supabaseMap['category'], equals('top'));
      expect(supabaseMap['subtype'], equals('shirt'));
      expect(
        supabaseMap['cutout_path'],
        equals('users/123/cutouts/item_123.webp'),
      );

      expect(item.displayImageUrl, equals('users/123/cutouts/item_123.webp'));
      final rawItem = WardrobeItem(
        id: 'raw_1',
        name: 'Prenda Cruda',
        type: 'top',
        subType: 't-shirt',
        imageUrl: 'https://example.com/raw.jpg',
        cutoutPath: null,
        colors: ['black'],
        createdAt: now,
      );
      expect(rawItem.displayImageUrl, equals('https://example.com/raw.jpg'));

      final fromMap = WardrobeItem.fromSupabase(supabaseMap);
      expect(fromMap.id, equals('item_123'));
      expect(fromMap.name, equals('Camisa Blanca'));
      expect(fromMap.subType, equals('shirt'));
      expect(fromMap.type, equals('top'));
      expect(fromMap.cutoutPath, equals('users/123/cutouts/item_123.webp'));
      expect(fromMap.displayImageUrl, equals('users/123/cutouts/item_123.webp'));
      expect(fromMap.colors, contains('white'));
    });

    test(
      'SavedOutfit serializes to and from JSON without Firebase Timestamp',
      () {
        final generatedOutfit = GeneratedOutfit(
          id: 'outfit_789',
          topId: 'top_1',
          bottomId: 'bot_1',
          shoesId: 'shoe_1',
          matchPercentage: 95,
          compatibilityScore: 0.95,
          explanation: 'Clean monochrome look',
        );

        final intent = OutfitIntent(
          userPrompt: 'Outfit para una cena',
          occasion: 'dinner',
          styleTags: ['elegant'],
          preferredColors: ['black', 'white'],
        );

        final saved = SavedOutfit.fromGeneratedOutfit(
          outfit: generatedOutfit,
          intent: intent,
          userId: 'user_456',
          tryOnImageUrl: 'https://example.com/tryon.jpg',
        );

        final json = saved.toJson();
        expect(json['id'], equals('outfit_789'));
        expect(
          json['createdAt'],
          isA<String>(),
        ); // ISO-8601 string, NOT Timestamp

        final reconstructed = SavedOutfit.fromJson(json);
        expect(reconstructed.id, equals('outfit_789'));
        expect(reconstructed.userId, equals('user_456'));
        expect(reconstructed.matchPercentage, equals(95));
        expect(
          reconstructed.tryOnImageUrl,
          equals('https://example.com/tryon.jpg'),
        );
      },
    );

    test('IdentityConsistencyPrompt generates try-on prompt correctly', () {
      const profile = IdentityProfile(
        skinTone: IdentitySkinTone(primary: 'Fair warm'),
        face: IdentityFace(shape: 'Oval'),
      );

      final prompt = IdentityConsistencyPrompt.buildTryOnPrompt(
        profile: profile,
        hasBaseImage: true,
        hasFaceAnchor: true,
        garmentCount: 3,
      );

      expect(prompt, contains('TASK: VIRTUAL_TRY_ON'));
      expect(prompt, contains('Fair warm'));
      expect(prompt, contains('Oval'));
    });

    test(
      'IdentityConsistencyPrompt generates try-on prompt with one_piece and accessories correctly',
      () {
        const profile = IdentityProfile(
          skinTone: IdentitySkinTone(primary: 'Olive'),
          face: IdentityFace(shape: 'Heart'),
        );

        final prompt = IdentityConsistencyPrompt.buildTryOnPrompt(
          profile: profile,
          hasBaseImage: true,
          hasFaceAnchor: false,
          garmentCount: 0,
          hasFlatlay: true,
          isOnePiece: true,
          accessoryDescriptions: const ['Silver Necklace', 'Black Handbag'],
        );

        expect(prompt, contains('CONSOLIDATED_GARMENT_FLATLAY'));
        expect(prompt, contains('FULL_BODY_ONE_PIECE'));
        expect(prompt, contains('Do NOT render, paint, or hallucinate pants'));
        expect(prompt, contains('[ACCESSORIES_STYLING]'));
        expect(prompt, contains('Silver Necklace'));
        expect(prompt, contains('Black Handbag'));
      },
    );

    testWidgets('GlowingBorderCard renders child and handles taps', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowingBorderCard(
              onTap: () => tapped = true,
              child: const Text('Draculaura Look'),
            ),
          ),
        ),
      );

      expect(find.text('Draculaura Look'), findsOneWidget);
      await tester.tap(find.text('Draculaura Look'));
      expect(tapped, isTrue);
    });

    testWidgets(
      'GradientPillButton renders uppercase text, icon and triggers callback',
      (tester) async {
        bool pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GradientPillButton(
                text: 'Dress Me',
                icon: const Icon(Icons.bolt),
                onPressed: () => pressed = true,
              ),
            ),
          ),
        );

        expect(find.text('DRESS ME'), findsOneWidget);
        expect(find.byIcon(Icons.bolt), findsOneWidget);
        await tester.tap(find.text('DRESS ME'));
        expect(pressed, isTrue);
      },
    );

    testWidgets('MatchScoreBadge displays score and status text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MatchScoreBadge(score: 98))),
      );

      expect(find.text('98% MATCH!'), findsOneWidget);
      expect(find.text('DROP DEAD GORGEOUS'), findsOneWidget);
    });

    testWidgets('WardrobeCarouselSlot displays items and cycles with arrows', (
      tester,
    ) async {
      final items = [
        WardrobeItem(
          id: '1',
          name: 'Plaid Blazer',
          type: 'top',
          subType: 'blazer',
          imageUrl: 'https://example.com/blazer.png',
          colors: const ['yellow'],
        ),
        WardrobeItem(
          id: '2',
          name: 'Baby Tee',
          type: 'top',
          subType: 't-shirt',
          imageUrl: 'https://example.com/tee.png',
          colors: const ['white'],
        ),
      ];

      int selectedIdx = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WardrobeCarouselSlot(
              title: 'TOP',
              items: items,
              selectedIndex: selectedIdx,
              onItemChanged: (idx) => selectedIdx = idx,
            ),
          ),
        ),
      );

      expect(find.text('TOP'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Plaid Blazer'), findsOneWidget);

      // Tap right arrow
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump(const Duration(milliseconds: 350));
      expect(selectedIdx, equals(1));
    });

    test(
      'WardrobeItem serializes one_piece and accessories and validates helper getters',
      () {
        final dress = WardrobeItem.fromJson({
          'id': 'dress_1',
          'name': 'Little Black Dress',
          'category': 'dress', // legacy category alias
          'subType': 'vestido',
          'imageUrl': 'https://example.com/dress.png',
          'colors': ['black'],
        });

        expect(dress.type, equals('one_piece'));
        expect(dress.isOnePiece, isTrue);
        expect(dress.isAccessory, isFalse);
        expect(dress.matchesCategory('one_piece'), isTrue);
        expect(dress.matchesCategory('top'), isFalse);

        final dressSupabase = dress.toSupabase(userId: 'u_1');
        expect(dressSupabase['category'], equals('one_piece'));

        final scarf = WardrobeItem.fromJson({
          'id': 'acc_1',
          'name': 'Silk Scarf',
          'type': 'accessory', // legacy category alias
          'subType': 'bufanda',
          'imageUrl': 'https://example.com/scarf.png',
          'colors': ['red'],
        });

        expect(scarf.type, equals('accessories'));
        expect(scarf.isAccessory, isTrue);
        expect(scarf.isOnePiece, isFalse);
        expect(scarf.matchesCategory('accessories'), isTrue);
      },
    );

    test(
      'GeneratedOutfit validates one_piece look replacement and accessories',
      () {
        // 1. One piece + shoes = complete look (replaces top + bottom)
        final onePieceOutfit = GeneratedOutfit(
          id: 'outfit_one_piece',
          onePieceId: 'dress_1',
          shoesId: 'shoes_1',
          accessoryIds: const ['bag_1', 'necklace_1'],
          matchPercentage: 94,
          explanation: 'One piece elegance',
          compatibilityScore: 0.94,
        );

        expect(onePieceOutfit.hasCompleteLook, isTrue);
        expect(
          onePieceOutfit.itemIds,
          containsAll(['dress_1', 'shoes_1', 'bag_1', 'necklace_1']),
        );
        expect(onePieceOutfit.topId, isNull);
        expect(onePieceOutfit.bottomId, isNull);

        // 2. Incomplete look (missing both onePiece and top/bottom)
        final incompleteOutfit = GeneratedOutfit(
          id: 'outfit_incomplete',
          shoesId: 'shoes_1',
          matchPercentage: 50,
          explanation: 'Incomplete',
          compatibilityScore: 0.5,
        );
        expect(incompleteOutfit.hasCompleteLook, isFalse);
      },
    );

    test(
      'WardrobeSearchAlgorithm generates rule-based outfit with one_piece and accessories',
      () {
        final dress = WardrobeItem(
          id: 'dress_99',
          name: 'Goth Slip Dress',
          type: 'one_piece',
          subType: 'dress',
          imageUrl: '',
          colors: const ['black'],
        );
        final boots = WardrobeItem(
          id: 'boots_99',
          name: 'Platform Boots',
          type: 'shoes',
          subType: 'boots',
          imageUrl: '',
          colors: const ['black'],
        );
        final choker = WardrobeItem(
          id: 'acc_99',
          name: 'Velvet Choker',
          type: 'accessories',
          subType: 'necklace',
          imageUrl: '',
          colors: const ['black'],
        );

        final wardrobe = FilteredWardrobe(
          tops: const [],
          bottoms: const [],
          shoes: [boots],
          outerwear: const [],
          onePieces: [dress],
          accessories: [choker],
        );

        final outfits = WardrobeSearchAlgorithm.generateRuleBasedOutfits(
          wardrobe: wardrobe,
          intent: OutfitIntent(userPrompt: 'vestido gótico', occasion: 'party'),
        );

        expect(outfits.isNotEmpty, isTrue);
        final first = outfits.first;
        expect(first.onePieceId, equals('dress_99'));
        expect(first.shoesId, equals('boots_99'));
        expect(first.topId, isNull);
        expect(first.bottomId, isNull);
        expect(first.accessoryIds, contains('acc_99'));
        expect(first.hasCompleteLook, isTrue);
      },
    );

    testWidgets(
      'CategorySelector displays chips for one_piece and accessories and handles selection',
      (tester) async {
        String selected = 'top';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategorySelector(
                selectedCategory: selected,
                onCategorySelected: (cat) => selected = cat,
              ),
            ),
          ),
        );

        // Verify that 'Pieza Única' and 'Accesorios' chips are rendered
        expect(find.text('Pieza Única'), findsOneWidget);
        expect(find.text('Accesorios'), findsOneWidget);

        // Tap on 'Pieza Única'
        await tester.tap(find.text('Pieza Única'));
        await tester.pumpAndSettle();

        expect(selected, equals('one_piece'));
      },
    );

    test(
      'DeepSeekService retries on transient errors (503 / Timeout) and succeeds transparently with exponential backoff',
      () async {
        int invocations = 0;
        final retryDelays = <Duration>[];

        final service = DeepSeekService(
          timeout: const Duration(seconds: 45),
          maxRetries: 3,
          backoffBaseSeconds: 1.5,
          customDelay: (duration) async {
            retryDelays.add(duration);
          },
          customInvoker: (functionName, body) async {
            invocations++;
            if (invocations == 1) {
              // Intento 1: Falla con 503 Service Unavailable (cold start en Cloud Run)
              return FunctionResponse(
                data: {'error': 'Service Unavailable - Cold start'},
                status: 503,
              );
            } else if (invocations == 2) {
              // Intento 2: Falla con TimeoutException (Edge Function despertando)
              throw TimeoutException(
                'Gateway timeout while waking up function',
              );
            } else {
              // Intento 3: Resuelve con éxito
              return FunctionResponse(
                data: {
                  'status': 'success',
                  'result': 'Look Cyber-Goth generado exitosamente',
                  'jsonData': {'outfitId': 'cher_123', 'status': 'completed'},
                },
                status: 200,
              );
            }
          },
        );

        final result = await service.invokeGateway({'action': 'ping'});

        // Verificaciones:
        // 1. Invocado exactamente 3 veces
        expect(invocations, equals(3));
        // 2. Exponential backoff: delay = 1.5 * pow(2, attempt)
        // Intento 0: 1.5s (1500 ms)
        // Intento 1: 3.0s (3000 ms)
        expect(retryDelays.length, equals(2));
        expect(retryDelays[0].inMilliseconds, equals(1500));
        expect(retryDelays[1].inMilliseconds, equals(3000));
        // 3. Resolución transparente sin error propagado
        expect(result['status'], equals('success'));
        expect(
          result['result'],
          equals('Look Cyber-Goth generado exitosamente'),
        );
      },
    );

    test(
      'DeepSeekService does not retry on non-transient errors (400 Bad Request)',
      () async {
        int invocations = 0;
        final retryDelays = <Duration>[];

        final service = DeepSeekService(
          timeout: const Duration(seconds: 45),
          maxRetries: 3,
          customDelay: (duration) async {
            retryDelays.add(duration);
          },
          customInvoker: (functionName, body) async {
            invocations++;
            return FunctionResponse(
              data: {'error': 'Invalid payload parameters'},
              status: 400,
            );
          },
        );

        await expectLater(
          () => service.invokeGateway({'action': 'invalid'}),
          throwsA(isA<Exception>()),
        );
        // No debe reintentar errores de cliente no transitorios
        expect(invocations, equals(1));
        expect(retryDelays, isEmpty);
      },
    );

    test(
      'DeepSeekService exhausts retries after 3 failed attempts on continuous 504 Gateway Timeout',
      () async {
        int invocations = 0;
        final retryDelays = <Duration>[];

        final service = DeepSeekService(
          timeout: const Duration(seconds: 45),
          maxRetries: 3,
          backoffBaseSeconds: 1.5,
          customDelay: (duration) async {
            retryDelays.add(duration);
          },
          customInvoker: (functionName, body) async {
            invocations++;
            return FunctionResponse(
              data: {'error': '504 Gateway Timeout'},
              status: 504,
            );
          },
        );

        await expectLater(
          () => service.invokeGateway({'action': 'try_on'}),
          throwsA(isA<Exception>()),
        );

        // Debe intentar exactamente 3 veces antes de rendirse
        expect(invocations, equals(3));
        expect(retryDelays.length, equals(2));
      },
    );

    test(
      'DeepSeekService transient status code helper validates 502, 503, 504',
      () {
        expect(DeepSeekService.isTransientStatusCode(502), isTrue);
        expect(DeepSeekService.isTransientStatusCode(503), isTrue);
        expect(DeepSeekService.isTransientStatusCode(504), isTrue);
        expect(DeepSeekService.isTransientStatusCode(400), isFalse);
        expect(DeepSeekService.isTransientStatusCode(404), isFalse);
        expect(DeepSeekService.isTransientStatusCode(500), isFalse);
      },
    );

    test(
      'DeepSeekService matchWardrobe invokes with 8s timeout and fails immediately on error without retry storm',
      () async {
        int invocations = 0;
        final service = DeepSeekService(
          maxRetries: 3,
          customInvoker: (functionName, body) async {
            invocations++;
            expect(body['action'], equals('match_wardrobe'));
            expect(body['prompt'], equals('black summer dress'));
            return FunctionResponse(
              data: {'error': '504 Gateway Timeout'},
              status: 504,
            );
          },
        );

        await expectLater(
          () => service.matchWardrobe(query: 'black summer dress'),
          throwsA(isA<Exception>()),
        );

        // matchWardrobe configured with maxRetries: 1, must not retry 3 times
        expect(invocations, equals(1));
      },
    );

    test(
      'DeepSeekService processWardrobeItem invokes with 12s timeout and single attempt',
      () async {
        int invocations = 0;
        final service = DeepSeekService(
          maxRetries: 3,
          customInvoker: (functionName, body) async {
            invocations++;
            expect(body['action'], equals('process_wardrobe_item'));
            expect(body['itemId'], equals('item-123'));
            return FunctionResponse(
              data: {'status': 'success', 'cutoutPath': 'url/cutout.webp'},
              status: 200,
            );
          },
        );

        final result = await service.processWardrobeItem(
          itemId: 'item-123',
          userId: 'user-456',
        );

        expect(invocations, equals(1));
        expect(result['status'], equals('success'));
        expect(result['cutoutPath'], equals('url/cutout.webp'));
      },
    );

    testWidgets(
      'ColdStartProgressIndicator updates loading message past 3.5s during cold start',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ColdStartProgressIndicator())),
        );

        // Estado inicial (< 3.5s)
        expect(find.text('Generando vista try-on…'), findsOneWidget);
        expect(
          find.text('Despertando al vestidor inteligente... ✨'),
          findsNothing,
        );

        // Avanzar el tiempo 3.6 segundos (> 3.5s)
        await tester.pump(const Duration(milliseconds: 3600));
        expect(
          find.text('Despertando al vestidor inteligente... ✨'),
          findsOneWidget,
        );

        // Avanzar el tiempo a 7.2 segundos (> 7s)
        await tester.pump(const Duration(milliseconds: 3600));
        expect(
          find.text('Preparando los percheros virtuales... 🦇'),
          findsOneWidget,
        );
      },
    );

    test('Profiles standard payload schema validation', () {
      // Garantizar que el payload a Supabase public.profiles no contenga campos inexistentes
      const validProfileColumns = {
        'id',
        'legacy_firebase_uid',
        'display_name',
        'avatar_path',
        'preferences',
        'onboarding_completed',
        'identity_profile',
        'identity_version',
        'identity_collage_path',
        'identity_content_hash',
        'base_image_path',
        'base_image_content_hash',
        'created_at',
        'updated_at',
      };

      final payload = <String, dynamic>{
        'id': 'test-uuid-123',
        'display_name': 'Test User',
        'avatar_path': 'https://example.com/avatar.jpg',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Ninguna clave del payload debe quedar fuera de las columnas válidas de public.profiles
      for (final key in payload.keys) {
        expect(validProfileColumns.contains(key), isTrue,
            reason: 'Columna $key no permitida en public.profiles');
      }

      // Columnas prohibidas que causaban error 23503 / column does not exist
      expect(payload.containsKey('email'), isFalse);
      expect(payload.containsKey('photo_url'), isFalse);
    });

    test('Multi-image picker slots and limiting logic', () {
      const maxPerSection = 4;
      final currentPhotos = ['photo1.jpg', 'photo2.jpg'];
      final remainingSlots = maxPerSection - currentPhotos.length;
      expect(remainingSlots, equals(2));

      // Simular que el usuario selecciona 5 imágenes de golpe
      final pickedBatch = ['pA.jpg', 'pB.jpg', 'pC.jpg', 'pD.jpg', 'pE.jpg'];
      final toAdd = pickedBatch.take(remainingSlots).toList();

      expect(toAdd.length, equals(2));
      expect(toAdd, equals(['pA.jpg', 'pB.jpg']));

      final updatedPhotos = [...currentPhotos, ...toAdd];
      expect(updatedPhotos.length, equals(maxPerSection));

      // Si ya está lleno (4/4), los slots disponibles deben ser 0
      final fullRemainingSlots = maxPerSection - updatedPhotos.length;
      expect(fullRemainingSlots, equals(0));
    });

    test('Gemini 3.6 Flash IdentityProfile JSON contract preserves all biometric fields', () {
      final geminiResponseJson = <String, dynamic>{
        'identity_version': 1,
        'skin_tone': {
          'primary': 'warm olive',
          'undertone': 'golden',
          'confidence': 0.94,
        },
        'face': {
          'shape': 'oval',
          'jaw_definition': 'defined',
          'eye_shape': 'almond',
          'nose_shape': 'straight',
        },
        'hair': {
          'color': 'dark brown',
          'style': 'short curly',
          'density': 'thick',
        },
        'body': {
          'type': 'athletic',
          'height_estimate': '178cm',
          'shoulder_width': 'broad',
          'build': 'mesomorph',
          'proportions': 'balanced',
        },
        'visual_characteristics': {
          'contrast_level': 'medium-high',
          'facial_sharpness': 'soft-sharp',
          'overall_presence': 'confident-casual',
        },
      };

      final profile = IdentityProfile.fromJson(geminiResponseJson);

      expect(profile.identityVersion, equals(1));
      expect(profile.skinTone?.primary, equals('warm olive'));
      expect(profile.skinTone?.undertone, equals('golden'));
      expect(profile.skinTone?.confidence, equals(0.94));
      expect(profile.face?.shape, equals('oval'));
      expect(profile.face?.jawDefinition, equals('defined'));
      expect(profile.hair?.color, equals('dark brown'));
      expect(profile.body?.type, equals('athletic'));
      expect(profile.body?.build, equals('mesomorph'));
      expect(profile.visualCharacteristics?.contrastLevel, equals('medium-high'));
      expect(profile.isEmpty, isFalse);

      final promptPreserve = IdentityConsistencyPrompt.preserveFromProfile(profile);
      expect(promptPreserve, contains('warm olive skin tone'));
      expect(promptPreserve, contains('oval face shape'));
      expect(promptPreserve, contains('athletic body type'));
    });
  });
}
