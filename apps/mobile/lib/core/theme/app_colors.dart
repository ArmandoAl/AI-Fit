import 'package:flutter/material.dart';

/// Dark Glam / Y2K Cyber-Goth design tokens (Monster High x Clueless 90s).
///
/// Palette:
/// - Obsidiana Ciruela ultranegro canvas (#120E17)
/// - Deep plum velvet card surfaces (#1D1626)
/// - Neon Draculaura magenta (#FF2A85 / #FF1B8D)
/// - Frankie electric mint (#00F5D4)
/// - Electric purple (#9B2BEE)
/// - Ash lilac text & muted metadata (#A698B8)
/// - Pure ivory highlights (#FDFBFE)
class AppColors {
  AppColors._();

  // —— Canvas & Surfaces ——
  /// Canvas / Background Principal: Obsidiana Ciruela ultranegro
  static const Color background = Color(0xFF120E17);
  static const Color onBackground = Color(0xFFFDFBFE);

  /// Superficie de Tarjetas / Cards: ciruela profundo
  static const Color surface = Color(0xFF1D1626);
  static const Color cardBackground = Color(0xFF1D1626);
  static const Color onSurface = Color(0xFFFDFBFE);
  static const Color onSurfaceVariant = Color(0xFFA698B8);

  static const Color surfaceDim = Color(0xFF0E0B12);
  static const Color surfaceBright = Color(0xFF281F34);
  static const Color surfaceContainerLowest = Color(0xFF09070C);
  static const Color surfaceContainerLow = Color(0xFF16101E);
  static const Color surfaceContainer = Color(0xFF1D1626);
  static const Color surfaceContainerHigh = Color(0xFF261D32);
  static const Color surfaceContainerHighest = Color(0xFF332743);
  static const Color surfaceVariant = Color(0xFF261D32);

  // —— Dark Glam Accents ——
  /// Magenta neón Draculaura
  static const Color neonMagenta = Color(0xFFFF2A85);

  /// Menta eléctrico Frankie
  static const Color neonMint = Color(0xFF00F5D4);

  /// Fucsia cibernético brillante para degradados principales
  static const Color cyberPink = Color(0xFFFF1B8D);

  /// Púrpura eléctrico de alta vibración
  static const Color electricPurple = Color(0xFF9B2BEE);

  /// Acento activo para iconos y elementos seleccionados
  static const Color accentActive = Color(0xFFFF2A85);

  /// Acento inactivo para elementos no seleccionados
  static const Color accentInactive = Color(0xFF796A8D);

  // —— Brand & Material Mappings ——
  static const Color primary = Color(0xFFFF2A85);
  static const Color onPrimary = Color(0xFFFDFBFE);
  static const Color primaryContainer = Color(0xFF4A0E29);
  static const Color onPrimaryContainer = Color(0xFFFFD9E6);
  static const Color inversePrimary = Color(0xFFFF85B9);

  /// Textos secundarios y metadatos: Lila cenizo / Lavanda suave
  static const Color secondary = Color(0xFFA698B8);
  static const Color onSecondary = Color(0xFF120E17);
  static const Color secondaryContainer = Color(0xFF2E243D);
  static const Color onSecondaryContainer = Color(0xFFEADBFF);

  /// Iconos inactivos y bordes sutiles
  static const Color tertiary = Color(0xFF796A8D);
  static const Color onTertiary = Color(0xFFFDFBFE);

  // —— Accents de lujo adaptados a Dark Glam ——
  static const Color gold = Color(0xFFFF2A85);
  static const Color onGold = Color(0xFF120E17);
  static const Color goldSoft = Color(0xFF00F5D4);

  // —— Outlines & Borders ——
  static const Color border = Color(0xFF332742);
  static const Color outline = Color(0xFF4A385E);
  static const Color outlineVariant = Color(0xFF271C33);

  // —— Inverse ——
  static const Color inverseSurface = Color(0xFFFDFBFE);
  static const Color onInverseSurface = Color(0xFF120E17);

  // —— Semantic Status ——
  static const Color error = Color(0xFFFF4D6D);
  static const Color onError = Color(0xFFFDFBFE);
  static const Color errorContainer = Color(0xFF4D1022);
  static const Color onErrorContainer = Color(0xFFFFD9E2);
  static const Color success = Color(0xFF00F5D4);

  // —— Legacy text aliases ——
  static const Color primaryVariant = primaryContainer;
  static const Color textPrimary = Color(0xFFFDFBFE);
  static const Color textSecondary = Color(0xFFA698B8);
  static const Color textTertiary = Color(0xFF796A8D);

  // —— Gradients ——
  /// Gradiente Clueless-Goth de borde: Magenta neón a Menta eléctrico
  static const LinearGradient cluelessGothBorderGradient = LinearGradient(
    colors: [neonMagenta, neonMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente primario de botón (Dress Me / Try-On): Fucsia a Púrpura eléctrico
  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [cyberPink, electricPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Gradiente sutil de fondo para tarjetas dark glam
  static const LinearGradient cardBackgroundGradient = LinearGradient(
    colors: [Color(0xFF221A2D), Color(0xFF181220)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // —— Shadows & Glows ——
  /// Glow difuso para el botón principal (#FF1B8D, blur 20, radio 16, opacidad 0.4)
  static const List<BoxShadow> primaryButtonGlow = [
    BoxShadow(
      color: Color(0x66FF1B8D),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];

  /// Glow sutil para tarjetas con borde neon
  static const List<BoxShadow> neonBorderGlow = [
    BoxShadow(
      color: Color(0x33FF2A85),
      blurRadius: 16,
      spreadRadius: -4,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x1F00F5D4),
      blurRadius: 20,
      spreadRadius: -6,
      offset: Offset(0, 10),
    ),
  ];

  /// Material 3 ColorScheme dark para [ThemeData.dark].
  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        inverseSurface: inverseSurface,
        onInverseSurface: onInverseSurface,
        inversePrimary: inversePrimary,
        surfaceContainerHighest: surfaceContainerHighest,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainer: surfaceContainer,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainerLowest: surfaceContainerLowest,
      );
}
