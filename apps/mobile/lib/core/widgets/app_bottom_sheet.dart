import 'package:flutter/material.dart';
import 'luxury_bottom_sheet.dart';

/// API unificada — delega al sheet premium animado.
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    required Widget child,
    bool isScrollControlled = false,
    double? maxHeightFraction,
    EdgeInsetsGeometry? padding,
  }) {
    if (maxHeightFraction != null) {
      return LuxuryBottomSheet.showDraggable<T>(
        context: context,
        title: title,
        subtitle: subtitle,
        initialChildSize: maxHeightFraction,
        builder: (_) => child,
      );
    }
    return LuxuryBottomSheet.show<T>(
      context: context,
      title: title,
      subtitle: subtitle,
      padding: padding,
      child: child,
    );
  }

  static Future<T?> showDraggable<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    required Widget Function(ScrollController scrollController) builder,
    double initialChildSize = 0.88,
  }) {
    return LuxuryBottomSheet.showDraggable<T>(
      context: context,
      title: title,
      subtitle: subtitle,
      initialChildSize: initialChildSize,
      builder: builder,
    );
  }
}
