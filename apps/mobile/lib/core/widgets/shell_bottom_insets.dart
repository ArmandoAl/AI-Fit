import 'package:flutter/material.dart';

/// Espacio reservado por la barra inferior flotante del shell.
class ShellBottomInsets {
  ShellBottomInsets._();

  /// Altura visual de la píldora (handle + fila de ítems).
  static const double barHeight = 66;

  /// Margen inferior de la píldora sobre el safe area.
  static const double bottomMargin = 6;

  /// Espacio extra recomendado para listas / FAB.
  static const double scrollExtra = 12;

  /// Total que debe usarse como padding inferior en scroll views.
  static double scrollPadding(BuildContext context) {
    return barHeight +
        bottomMargin +
        MediaQuery.paddingOf(context).bottom +
        scrollExtra;
  }

  /// Padding extra para pantallas con FAB sobre el grid.
  static double withFab(BuildContext context, {double fabClearance = 56}) {
    return scrollPadding(context) + fabClearance;
  }
}
