import 'package:flutter/scheduler.dart';

/// Yields so the UI isolate can paint frames between heavy work chunks.
Future<void> yieldToUi({int frames = 1}) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(Duration.zero);
    final binding = SchedulerBinding.instance;
    await binding.endOfFrame;
  }
}
