/// Paleta canónica (inglés en DB/IA) + etiquetas en español para la UI.
class WardrobePalette {
  WardrobePalette._();

  static const List<String> standardColors = [
    'black',
    'white',
    'gray',
    'navy',
    'blue',
    'red',
    'green',
    'brown',
    'beige',
    'pink',
    'yellow',
    'orange',
    'purple',
  ];

  static const List<String> standardStyleTags = [
    'casual',
    'formal',
    'sporty',
    'elegant',
    'streetwear',
    'minimalist',
    'vintage',
    'bohemian',
  ];

  static const List<String> standardSeasons = [
    'spring',
    'summer',
    'fall',
    'winter',
  ];

  static final Map<String, String> _colorAliases = {
    'tan': 'beige',
    'khaki': 'beige',
    'camel': 'beige',
    'sand': 'beige',
    'cream': 'beige',
    'ivory': 'beige',
    'off_white': 'beige',
    'off-white': 'beige',
    'ecru': 'beige',
    'taupe': 'brown',
    'chocolate': 'brown',
    'coffee': 'brown',
    'maroon': 'red',
    'burgundy': 'red',
    'crimson': 'red',
    'charcoal': 'gray',
    'grey': 'gray',
    'silver': 'gray',
    'slate': 'gray',
    'denim': 'navy',
    'indigo': 'navy',
    'teal': 'green',
    'olive': 'green',
    'lime': 'green',
    'mint': 'green',
    'coral': 'orange',
    'peach': 'orange',
    'lavender': 'purple',
    'violet': 'purple',
    'magenta': 'pink',
    'rose': 'pink',
    'gold': 'yellow',
    'mustard': 'yellow',
    'sky_blue': 'blue',
    'light_blue': 'blue',
    'royal_blue': 'blue',
  };

  /// Etiquetas en español para chips y listas (clave = slug inglés en Firestore).
  static const Map<String, String> colorLabelsEs = {
    'black': 'Negro',
    'white': 'Blanco',
    'gray': 'Gris',
    'navy': 'Azul marino',
    'blue': 'Azul',
    'red': 'Rojo',
    'green': 'Verde',
    'brown': 'Marrón',
    'beige': 'Beige',
    'pink': 'Rosa',
    'yellow': 'Amarillo',
    'orange': 'Naranja',
    'purple': 'Morado',
  };

  static const Map<String, String> styleTagLabelsEs = {
    'casual': 'Casual',
    'formal': 'Formal',
    'sporty': 'Deportivo',
    'elegant': 'Elegante',
    'streetwear': 'Streetwear',
    'minimalist': 'Minimalista',
    'vintage': 'Vintage',
    'bohemian': 'Bohemio',
  };

  static const Map<String, String> seasonLabelsEs = {
    'spring': 'Primavera',
    'summer': 'Verano',
    'fall': 'Otoño',
    'winter': 'Invierno',
  };

  static const Map<String, String> typeLabelsEs = {
    'top': 'Superior',
    'bottom': 'Inferior',
    'one_piece': 'Pieza Única',
    'one-piece': 'Pieza Única',
    'shoes': 'Calzado',
    'outerwear': 'Abrigo',
    'accessories': 'Accesorios',
    'accessory': 'Accesorios',
  };

  static const Map<String, String> subtypeLabelsEs = {
    // one_piece
    'dress': 'Vestido',
    'jumpsuit': 'Enterizo',
    'romper': 'Romper',
    'vestido': 'Vestido',
    'enterizo': 'Enterizo',
    // accessories
    'scarf': 'Bufanda',
    'earrings': 'Aretes / Joyas',
    'necklace': 'Collar',
    'bag': 'Bolso',
    'belt': 'Cinturón',
    'bufanda': 'Bufanda',
    'aretes': 'Aretes / Joyas',
    'collar': 'Collar',
    'bolso': 'Bolso',
    'cinturon': 'Cinturón',
    // tops
    't-shirt': 'Camiseta',
    'shirt': 'Camisa',
    'sweater': 'Suéter',
    'hoodie': 'Sudadera',
    'tank-top': 'Sin mangas',
    'blouse': 'Blusa',
    // bottoms
    'jeans': 'Jeans',
    'pants': 'Pantalones',
    'shorts': 'Shorts',
    'skirt': 'Falda',
    'chinos': 'Chinos',
    'sweatpants': 'Pantalón deportivo',
    // shoes
    'sneakers': 'Zapatillas / Tenis',
    'boots': 'Botas',
    'sandals': 'Sandalias',
    'dress-shoes': 'Zapatos formales',
    'sports-shoes': 'Calzado deportivo',
    // outerwear
    'jacket': 'Chaqueta',
    'coat': 'Abrigo',
    'blazer': 'Blazer',
    'cardigan': 'Cárdigan',
    'vest': 'Chaleco',
  };

  static const Map<String, String> occasionLabelsEs = {
    'casual': 'Casual',
    'formal': 'Formal',
    'sport': 'Deporte',
    'party': 'Fiesta',
    'work': 'Trabajo',
    'date': 'Cita',
    'everyday': 'Diario',
  };

  static const Map<String, String> weatherLabelsEs = {
    'sunny': 'Soleado',
    'rainy': 'Lluvia',
    'cold': 'Frío',
    'warm': 'Calor',
    'hot': 'Caluroso',
    'cloudy': 'Nublado',
  };

  static final Map<String, String> _colorEsToEn = {
    'negro': 'black',
    'blanco': 'white',
    'gris': 'gray',
    'azul_marino': 'navy',
    'azul marino': 'navy',
    'marino': 'navy',
    'azul': 'blue',
    'rojo': 'red',
    'verde': 'green',
    'marron': 'brown',
    'marrón': 'brown',
    'beige': 'beige',
    'rosa': 'pink',
    'amarillo': 'yellow',
    'naranja': 'orange',
    'morado': 'purple',
    'violeta': 'purple',
  };

  static final Map<String, String> _styleTagEsToEn = {
    'deportivo': 'sporty',
    'elegante': 'elegant',
    'minimalista': 'minimalist',
    'bohemio': 'bohemian',
    'informal': 'casual',
  };

  static final Map<String, String> _seasonEsToEn = {
    'primavera': 'spring',
    'verano': 'summer',
    'otoño': 'fall',
    'otono': 'fall',
    'invierno': 'winter',
  };

  static final Map<String, String> _occasionEsToEn = {
    'deporte': 'sport',
    'deportivo': 'sport',
    'fiesta': 'party',
    'trabajo': 'work',
    'oficina': 'work',
    'cita': 'date',
    'diario': 'everyday',
    'informal': 'casual',
  };

  static String labelColor(String slug) =>
      colorLabelsEs[slug] ?? _titleCase(slug);

  static String labelStyleTag(String slug) =>
      styleTagLabelsEs[slug] ?? _titleCase(slug);

  static String labelSeason(String slug) =>
      seasonLabelsEs[slug] ?? _titleCase(slug);

  static String labelType(String slug) =>
      typeLabelsEs[slug] ?? _titleCase(slug);

  static String labelSubtype(String slug) =>
      subtypeLabelsEs[slug.toLowerCase()] ?? _titleCase(slug);

  static String labelOccasion(String slug) =>
      occasionLabelsEs[slug] ?? _titleCase(slug);

  static String labelWeather(String slug) =>
      weatherLabelsEs[slug] ?? _titleCase(slug);

  static String normalizeType(String raw) {
    final key = raw.trim().toLowerCase().replaceAll('-', '_');
    if (key == 'dress' || key == 'vestido' || key == 'jumpsuit' || key == 'enterizo' || key == 'one_piece') {
      return 'one_piece';
    }
    if (key == 'accessory' || key == 'accessories' || key == 'accesorio' || key == 'accesorios') {
      return 'accessories';
    }
    return key;
  }

  static String _titleCase(String slug) {
    if (slug.isEmpty) return slug;
    return slug
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static final Map<String, String> _styleTagAliases = {
    'everyday': 'casual',
    'utilitarian': 'casual',
    'relaxed': 'casual',
    'smart_casual': 'casual',
    'business_casual': 'formal',
    'athletic': 'sporty',
    'active': 'sporty',
    'preppy': 'elegant',
    'classic': 'elegant',
    'edgy': 'streetwear',
    'urban': 'streetwear',
    'boho': 'bohemian',
    'retro': 'vintage',
  };

  static String normalizeColor(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (standardColors.contains(key)) return key;
    if (_colorEsToEn.containsKey(key)) return _colorEsToEn[key]!;
    final spaced = raw.trim().toLowerCase();
    if (_colorEsToEn.containsKey(spaced)) return _colorEsToEn[spaced]!;
    return _colorAliases[key] ?? key;
  }

  static String normalizeStyleTag(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (standardStyleTags.contains(key)) return key;
    if (_styleTagEsToEn.containsKey(key)) return _styleTagEsToEn[key]!;
    return _styleTagAliases[key] ?? key;
  }

  static String normalizeSeason(String raw) {
    final key = raw.trim().toLowerCase();
    if (standardSeasons.contains(key)) return key;
    if (_seasonEsToEn.containsKey(key)) return _seasonEsToEn[key]!;
    return key;
  }

  static String? normalizeOccasion(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final key = raw.trim().toLowerCase();
    const en = ['casual', 'formal', 'sport', 'party', 'work', 'date', 'everyday'];
    if (en.contains(key)) return key;
    return _occasionEsToEn[key] ?? key;
  }

  static String? normalizeWeather(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final key = raw.trim().toLowerCase();
    const en = ['sunny', 'rainy', 'cold', 'warm', 'hot', 'cloudy'];
    if (en.contains(key)) return key;
    const es = {'soleado': 'sunny', 'lluvia': 'rainy', 'lluvioso': 'rainy', 'frío': 'cold', 'frio': 'cold', 'calor': 'warm', 'caluroso': 'hot', 'nublado': 'cloudy'};
    return es[key] ?? key;
  }

  /// Maps AI colors to palette; keeps unknown only if no alias exists.
  static List<String> normalizeColors(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final c in raw) {
      final n = normalizeColor(c);
      if (n.isEmpty || seen.contains(n)) continue;
      seen.add(n);
      result.add(n);
    }
    return result;
  }

  static List<String> normalizeStyleTags(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final t in raw) {
      final n = normalizeStyleTag(t);
      if (n.isEmpty || seen.contains(n)) continue;
      seen.add(n);
      result.add(n);
    }
    return result;
  }

  static List<String> normalizeSeasons(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final s in raw) {
      final n = normalizeSeason(s);
      if (!standardSeasons.contains(n) || seen.contains(n)) continue;
      seen.add(n);
      result.add(n);
    }
    return result;
  }

  static List<String> customColors(List<String> colors) {
    return colors
        .where((c) => !standardColors.contains(c))
        .toList();
  }

  static List<String> customStyleTags(List<String> tags) {
    return tags
        .where((t) => !standardStyleTags.contains(t))
        .toList();
  }

  static String get colorsForPrompt =>
      standardColors.join(', ');

  static String get styleTagsForPrompt =>
      standardStyleTags.join(', ');
}
