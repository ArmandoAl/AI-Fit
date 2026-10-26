class SavedOutfit {
  final String id;
  final String userId;
  final String tryOnImageUrl;
  final List<String> colors;
  final List<String> styleTags;
  final String? occasion;
  final String? season;
  final String? weather;
  final int matchPercentage;
  final double compatibilityScore;

  SavedOutfit({
    required this.id,
    required this.userId,
    required this.tryOnImageUrl,
    required this.colors,
    required this.styleTags,
    required this.occasion,
    required this.season,
    required this.weather,
    required this.matchPercentage,
    required this.compatibilityScore,
  });

  factory SavedOutfit.fromJson(Map<String, dynamic> json) {
    return SavedOutfit(
      id: json['id'],
      userId: json['userId'],
      tryOnImageUrl: json['tryOnImageUrl'],
      colors: json['colors'],
      styleTags: json['styleTags'],
      occasion: json['occasion'],
      season: json['season'],
      weather: json['weather'],
      matchPercentage: json['matchPercentage'],
      compatibilityScore: json['compatibilityScore'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tryOnImageUrl': tryOnImageUrl,
      'colors': colors,
      'styleTags': styleTags,
      'occasion': occasion,
      'season': season,
      'weather': weather,
      'matchPercentage': matchPercentage,
      'compatibilityScore': compatibilityScore,
    };
  }

  @override
  String toString() {
    return 'SavedOutfit(id: $id, userId: $userId, tryOnImageUrl: $tryOnImageUrl, colors: $colors, styleTags: $styleTags, occasion: $occasion, season: $season, weather: $weather, matchPercentage: $matchPercentage, compatibilityScore: $compatibilityScore)';
  }
}
