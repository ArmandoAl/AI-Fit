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
PERSON IDENTITY — use the person photos only as identity and body references:
- Keep the same recognizable person, natural facial features, skin tone, hair, glasses, and body proportions.
- Ignore clothing and fashion accessories in the person photos; the selected wardrobe item references define the outfit.
- Preserve real distinguishing features without copying pixels, freezing the expression, or making the face look retouched or synthetic.
- Keep personal items visible in the references (such as glasses); these are not permission to add fashion accessories.
- A natural expression and a reasonable pose change are allowed. Do not change the person's identity, age, body shape, or skin tone.
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
      final h = [
        hair?.color,
        hair?.style,
        hair?.density,
      ].whereType<String>().join(' ');
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
    bool isOnePiece = false,
    List<String> accessoryDescriptions = const [],
  }) {
    final onePieceRule = isOnePiece
        ? 'The selected outfit includes one one-piece garment. Do not add a separate top, pants, skirt, or other bottom.'
        : '';
    final accessories = accessoryDescriptions.isEmpty
        ? ''
        : 'Selected accessories, and only these: ${accessoryDescriptions.join(', ')}.';
    return '''
TASK: Create one new, photorealistic try-on photograph. Return a single image.

${buildTryOnBlock(profile)}
${profileJsonBlock(profile)}

SELECTED OUTFIT — these item references are authoritative:
Wear the selected wardrobe items supplied with this request. Preserve each item's actual color, silhouette, cut, material, pattern, and recognizable details. Keep each selected item recognizable; do not recolor, redesign, replace, omit, duplicate, or combine it with another garment.
Do not invent, substitute, or add clothing, jewelry, bags, hats, belts, or other fashion accessories. Include only the selected items. Personal identity features such as the person's glasses may remain.
$onePieceRule
$accessories

POSE AND SCENE:
A natural pose may vary from the person references, but pose changes never authorize outfit changes. Keep garments visible rather than hidden by crossed arms, pockets, props, or cropping. A separate user scene/pose request may guide only the pose and background; it must not change the selected outfit.

FRAMING AND OUTPUT:
Vertical 3:4 full-body fashion photograph, centered person, with head, complete outfit, and shoes inside frame. Use one coherent photographic scene and natural lighting. No text, captions, logos, watermarks, borders, split panels, product cutouts, collages, or moodboards.
''';
  }
}
