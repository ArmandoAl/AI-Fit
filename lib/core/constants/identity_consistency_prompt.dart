import 'dart:convert';

import '../../features/profile/domain/user_identity_profile.dart';

/// Identity preservation blocks for base image and try-on generation.
class IdentityConsistencyPrompt {
  IdentityConsistencyPrompt._();

  static const String seed = '''
IDENTITY CONSISTENCY (mandatory):
- same person
- same facial identity
- same skin tone
- same ethnicity
- same body proportions
- same hairstyle
''';

  static const String tryOnReinforcement = '''
IDENTITY PRESERVATION (highest priority — overrides outfit styling):
Identity preservation is MORE important than artistic stylization or fashion editorial look.

- Copy the face EXACTLY from the identity reference images. Do NOT invent a new face.
- Preserve exact skin tone. Do not lighten or darken skin.
- Preserve ethnicity. Do not alter ethnicity.
- Preserve facial proportions, bone structure, nose, eyes, lips, jaw.
- Preserve hairstyle, hair color, hairline, and hair density.
- Preserve ALL visible accessories from references (glasses, earrings, etc.).
- Preserve body type, shoulder width, height proportions, and build.
- The output person must be recognizable as the SAME individual.

Do NOT apply beauty retouching, skin smoothing, face swapping, or ethnic alteration.
Do NOT generate a generic model face.
''';

  static const String baseImageStyle = '''
VISUAL STYLE:
- Neutral, clean, realistic, premium ecommerce catalog look
- Even soft studio lighting — NOT cinematic or dramatic
- No editorial fashion styling, no heavy retouching, no stylization
''';

  static String preserveFromProfile(IdentityProfile? profile) {
    if (profile == null || profile.isEmpty) return '';

    final lines = <String>['Preserve exactly:'];

    final skin = profile.skinTone;
    if (skin?.primary != null) {
      lines.add('- ${skin!.primary} skin tone');
      if (skin.undertone != null) lines.add('- ${skin.undertone} undertone');
    }

    final face = profile.face;
    if (face?.shape != null) {
      lines.add('- ${face!.shape} face shape');
    }
    if (face?.jawDefinition != null) {
      lines.add('- ${face!.jawDefinition} jaw');
    }
    if (face?.eyeShape != null) lines.add('- ${face!.eyeShape} eyes');
    if (face?.noseShape != null) lines.add('- ${face!.noseShape} nose');

    final hair = profile.hair;
    if (hair?.color != null || hair?.style != null) {
      final h = [hair?.color, hair?.style, hair?.density]
          .whereType<String>()
          .join(' ');
      lines.add('- $h hair');
    }

    final body = profile.body;
    if (body?.type != null) lines.add('- ${body!.type} body type');
    if (body?.build != null) lines.add('- ${body!.build} build');
    if (body?.heightEstimate != null) {
      lines.add('- ${body!.heightEstimate} height');
    }
    if (body?.shoulderWidth != null) {
      lines.add('- ${body!.shoulderWidth} shoulders');
    }
    if (body?.proportions != null) {
      lines.add('- ${body!.proportions} proportions');
    }

    final visual = profile.visualCharacteristics;
    if (visual?.facialSharpness != null) {
      lines.add('- ${visual!.facialSharpness} facial sharpness');
    }
    if (visual?.contrastLevel != null) {
      lines.add('- ${visual!.contrastLevel} contrast');
    }

    return lines.length > 1 ? lines.join('\n') : '';
  }

  static String profileJsonBlock(IdentityProfile? profile) {
    if (profile == null || profile.isEmpty) return '';
    final json = const JsonEncoder.withIndent('  ').convert(profile.toJson());
    return '''
[IDENTITY_PROFILE_JSON]
Use this structured profile to lock identity. It must match the reference images:
$json
''';
  }

  static String tryOnImageRoles({
    required bool hasBaseImage,
    required bool hasFaceAnchor,
    required int garmentCount,
    bool hasFlatlay = false,
  }) {
    final lines = <String>['[INPUT_IMAGES — read in order]'];
    var index = 1;

    if (hasBaseImage) {
      lines.add(
        'Image $index: IDENTITY_BASE — full-body person template. '
        'This IS the person. Keep face, skin, hair, body, pose structure. '
        'ONLY clothing will change.',
      );
      index++;
    }

    if (hasFaceAnchor) {
      lines.add(
        'Image $index: FACE_ANCHOR — high-priority close-up face reference. '
        'Match eyes, nose, lips, jaw, glasses, and skin tone EXACTLY.',
      );
      index++;
    }

    if (hasFlatlay) {
      lines.add(
        'Image $index: CONSOLIDATED_GARMENT_FLATLAY — unified 2-image pipeline. '
        'Shows all outfit garments and accessories arranged on a clean white background. '
        'Transfer all items onto the person accurately.',
      );
    } else if (garmentCount > 0) {
      final end = index + garmentCount - 1;
      if (garmentCount == 1) {
        lines.add(
          'Image $index: GARMENT — apply this clothing item to the person.',
        );
      } else {
        lines.add(
          'Images $index–$end: GARMENTS — apply these clothing items to the person.',
        );
      }
    }

    return lines.join('\n');
  }

  static String buildBlock({IdentityProfile? profile, bool forTryOn = false}) {
    final parts = <String>[seed];
    if (forTryOn) parts.add(tryOnReinforcement);
    final preserve = preserveFromProfile(profile);
    if (preserve.isNotEmpty) parts.add(preserve);
    return parts.join('\n\n');
  }

  static String buildBaseImageBlock(IdentityProfile? profile) {
    return '${buildBlock(profile: profile)}\n\n$baseImageStyle';
  }

  static String buildTryOnBlock(IdentityProfile? profile) {
    return buildBlock(profile: profile, forTryOn: true);
  }

  /// Full try-on instruction block (aligned with base-image prompt quality).
  static String buildTryOnPrompt({
    required IdentityProfile? profile,
    required bool hasBaseImage,
    required bool hasFaceAnchor,
    required int garmentCount,
    bool hasFlatlay = false,
    bool isOnePiece = false,
    List<String> accessoryDescriptions = const [],
  }) {
    final identityBlock = buildTryOnBlock(profile);
    final imageRoles = tryOnImageRoles(
      hasBaseImage: hasBaseImage,
      hasFaceAnchor: hasFaceAnchor,
      garmentCount: garmentCount,
      hasFlatlay: hasFlatlay,
    );
    final jsonBlock = profileJsonBlock(profile);

    final onePieceSection = isOnePiece
        ? '''
[OUTFIT_TYPE_SPECIFICATION]
GARMENT_TYPE: FULL_BODY_ONE_PIECE (Dress / Jumpsuit / Romper)
CRITICAL INSTRUCTION: The subject is wearing a single continuous full-body dress or one-piece garment paired with footwear.
Do NOT render, paint, or hallucinate pants, trousers, jeans, shorts, skirts, or any separate bottom garments under any circumstances.
'''
        : '';

    final accessoriesSection = accessoryDescriptions.isNotEmpty
        ? '''
[ACCESSORIES_STYLING]
Include and style all accessories shown in the garment flat-lay:
${accessoryDescriptions.map((a) => '- $a').join('\n')}
The subject must wear or carry these accessories naturally (e.g. necklace worn around the neck, earrings on ears, handbag held in hand or over shoulder, scarf draped naturally).
'''
        : '';

    return '''
[OUTPUT_SPECIFICATIONS]
MODE: IMAGE_GENERATION
TASK: VIRTUAL_TRY_ON (identity-locked clothing swap — NOT a new person)
FORMAT: image/jpeg
ASPECT_RATIO: 3:4
QUALITY: PREMIUM_ECOMMERCE

$imageRoles

$identityBlock

$jsonBlock
$onePieceSection$accessoriesSection
[INSTRUCTION]
Perform a virtual try-on on the EXISTING person from the identity reference image(s).
Replace ONLY their clothing with the garment reference images.
The face and identity MUST remain the same person — recognizable and faithful to references.

[REQUIREMENTS]
- Identity match is the #1 priority — face must look like the reference person
- Apply garment colors, textures, and fit from garment images
- Full-body or 3/4 ecommerce catalog framing, neutral studio background
- Soft even lighting, natural skin texture, no beauty filters
- Realistic clothing drape and proportions on the SAME body
- If wearing a one-piece dress, drape seamlessly across the body down to the hemline with NO separate bottom garments
- Style any accessories naturally with authentic texture and placement

[AVOID]
- Generating a different face or generic model
- Skin lightening, ethnic alteration, face beautification
- Cinematic/editorial styling, dramatic shadows
- Ignoring glasses or visible accessories from face reference
- Hallucinating pants or trousers under a one-piece dress
- Omitting accessories present in the garment flat-lay

[FINAL_OBJECTIVE]
One photorealistic image of the SAME individual wearing the complete outfit.
''';
  }
}
