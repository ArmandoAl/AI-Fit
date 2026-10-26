/// Structured identity profile for virtual try-on (schema v1).
library;

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class IdentitySkinTone {
  final String? primary;
  final String? undertone;
  final double? confidence;

  const IdentitySkinTone({this.primary, this.undertone, this.confidence});

  factory IdentitySkinTone.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IdentitySkinTone();
    return IdentitySkinTone(
      primary: json['primary']?.toString(),
      undertone: json['undertone']?.toString(),
      confidence: _parseDouble(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (primary != null) 'primary': primary,
        if (undertone != null) 'undertone': undertone,
        if (confidence != null) 'confidence': confidence,
      };

  bool get isEmpty => toJson().isEmpty;
}

class IdentityFace {
  final String? shape;
  final String? jawDefinition;
  final String? eyeShape;
  final String? noseShape;

  const IdentityFace({
    this.shape,
    this.jawDefinition,
    this.eyeShape,
    this.noseShape,
  });

  factory IdentityFace.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IdentityFace();
    return IdentityFace(
      shape: json['shape']?.toString(),
      jawDefinition: json['jaw_definition']?.toString(),
      eyeShape: json['eye_shape']?.toString(),
      noseShape: json['nose_shape']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (shape != null) 'shape': shape,
        if (jawDefinition != null) 'jaw_definition': jawDefinition,
        if (eyeShape != null) 'eye_shape': eyeShape,
        if (noseShape != null) 'nose_shape': noseShape,
      };

  bool get isEmpty => toJson().isEmpty;
}

class IdentityHair {
  final String? color;
  final String? style;
  final String? density;

  const IdentityHair({this.color, this.style, this.density});

  factory IdentityHair.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IdentityHair();
    return IdentityHair(
      color: json['color']?.toString(),
      style: json['style']?.toString(),
      density: json['density']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color,
        if (style != null) 'style': style,
        if (density != null) 'density': density,
      };

  bool get isEmpty => toJson().isEmpty;
}

class IdentityBody {
  final String? type;
  final String? heightEstimate;
  final String? shoulderWidth;
  final String? build;
  final String? proportions;

  const IdentityBody({
    this.type,
    this.heightEstimate,
    this.shoulderWidth,
    this.build,
    this.proportions,
  });

  factory IdentityBody.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IdentityBody();
    return IdentityBody(
      type: json['type']?.toString(),
      heightEstimate: json['height_estimate']?.toString(),
      shoulderWidth: json['shoulder_width']?.toString(),
      build: json['build']?.toString(),
      proportions: json['proportions']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        if (heightEstimate != null) 'height_estimate': heightEstimate,
        if (shoulderWidth != null) 'shoulder_width': shoulderWidth,
        if (build != null) 'build': build,
        if (proportions != null) 'proportions': proportions,
      };

  bool get isEmpty => toJson().isEmpty;
}

class IdentityVisualCharacteristics {
  final String? contrastLevel;
  final String? facialSharpness;
  final String? overallPresence;

  const IdentityVisualCharacteristics({
    this.contrastLevel,
    this.facialSharpness,
    this.overallPresence,
  });

  factory IdentityVisualCharacteristics.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IdentityVisualCharacteristics();
    return IdentityVisualCharacteristics(
      contrastLevel: json['contrast_level']?.toString(),
      facialSharpness: json['facial_sharpness']?.toString(),
      overallPresence: json['overall_presence']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (contrastLevel != null) 'contrast_level': contrastLevel,
        if (facialSharpness != null) 'facial_sharpness': facialSharpness,
        if (overallPresence != null) 'overall_presence': overallPresence,
      };

  bool get isEmpty => toJson().isEmpty;
}

class IdentityProfile {
  static const int currentVersion = 1;

  final int? identityVersion;
  final IdentitySkinTone? skinTone;
  final IdentityFace? face;
  final IdentityHair? hair;
  final IdentityBody? body;
  final IdentityVisualCharacteristics? visualCharacteristics;

  const IdentityProfile({
    this.identityVersion,
    this.skinTone,
    this.face,
    this.hair,
    this.body,
    this.visualCharacteristics,
  });

  factory IdentityProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const IdentityProfile();

    final skin = IdentitySkinTone.fromJson(
      json['skin_tone'] is Map<String, dynamic>
          ? json['skin_tone'] as Map<String, dynamic>
          : null,
    );
    final face = IdentityFace.fromJson(
      json['face'] is Map<String, dynamic>
          ? json['face'] as Map<String, dynamic>
          : null,
    );
    final hair = IdentityHair.fromJson(
      json['hair'] is Map<String, dynamic>
          ? json['hair'] as Map<String, dynamic>
          : null,
    );
    final body = IdentityBody.fromJson(
      json['body'] is Map<String, dynamic>
          ? json['body'] as Map<String, dynamic>
          : null,
    );
    final visual = IdentityVisualCharacteristics.fromJson(
      json['visual_characteristics'] is Map<String, dynamic>
          ? json['visual_characteristics'] as Map<String, dynamic>
          : null,
    );

    return IdentityProfile(
      identityVersion: json['identity_version'] is int
          ? json['identity_version'] as int
          : int.tryParse(json['identity_version']?.toString() ?? ''),
      skinTone: skin.isEmpty ? null : skin,
      face: face.isEmpty ? null : face,
      hair: hair.isEmpty ? null : hair,
      body: body.isEmpty ? null : body,
      visualCharacteristics: visual.isEmpty ? null : visual,
    );
  }

  /// Reads `identityProfile` or migrates legacy `aiFaceProfile` / `aiBodyProfile`.
  factory IdentityProfile.fromFirestoreUser(Map<String, dynamic>? data) {
    if (data == null) return const IdentityProfile();

    if (data['identityProfile'] is Map<String, dynamic>) {
      return IdentityProfile.fromJson(
        data['identityProfile'] as Map<String, dynamic>,
      );
    }

    return _fromLegacy(
      data['aiFaceProfile'] as Map<String, dynamic>?,
      data['aiBodyProfile'] as Map<String, dynamic>?,
    );
  }

  static IdentityProfile _fromLegacy(
    Map<String, dynamic>? face,
    Map<String, dynamic>? body,
  ) {
    if (face == null && body == null) return const IdentityProfile();

    return IdentityProfile(
      identityVersion: 1,
      skinTone: face?['skin_tone'] != null
          ? IdentitySkinTone(primary: face!['skin_tone']?.toString())
          : null,
      face: face != null
          ? IdentityFace(
              shape: face['face_shape']?.toString(),
              eyeShape: face['eye_shape']?.toString(),
            )
          : null,
      hair: face != null
          ? IdentityHair(
              color: face['hair_color']?.toString(),
              style: face['hair_style']?.toString(),
            )
          : null,
      body: body != null
          ? IdentityBody(
              type: body['body_type']?.toString(),
              heightEstimate: body['height_estimate']?.toString(),
              shoulderWidth: body['shoulder_width']?.toString(),
              build: body['build']?.toString(),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'identity_version': identityVersion ?? currentVersion,
    };
    if (skinTone != null && !skinTone!.isEmpty) {
      map['skin_tone'] = skinTone!.toJson();
    }
    if (face != null && !face!.isEmpty) map['face'] = face!.toJson();
    if (hair != null && !hair!.isEmpty) map['hair'] = hair!.toJson();
    if (body != null && !body!.isEmpty) map['body'] = body!.toJson();
    if (visualCharacteristics != null && !visualCharacteristics!.isEmpty) {
      map['visual_characteristics'] = visualCharacteristics!.toJson();
    }
    return map;
  }

  bool get isEmpty {
    final hasData = (skinTone != null && !skinTone!.isEmpty) ||
        (face != null && !face!.isEmpty) ||
        (hair != null && !hair!.isEmpty) ||
        (body != null && !body!.isEmpty) ||
        (visualCharacteristics != null && !visualCharacteristics!.isEmpty);
    return !hasData;
  }
}
