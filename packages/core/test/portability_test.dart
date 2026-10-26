import 'dart:io';

import 'package:test/test.dart';

/// El core debe poder compilarse a JS/Wasm y ejecutarse en la VM sin Flutter ni APIs de plataforma.
void main() {
  final banned = RegExp(r'''import\s+['"](package:flutter[^'"]*|dart:ui|dart:io|dart:html|dart:js[^'"]*|dart:isolate|package:web[^'"]*|package:(supabase_flutter|google_sign_in|image_picker|shared_preferences|path_provider|flutter_bloc|go_router|dio)[^'"]*)['"]''');

  test('ningún archivo de lib importa Flutter, dart:ui, dart:io ni plugins', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final line in file.readAsLinesSync()) {
        if (banned.hasMatch(line)) offenders.add('${file.path}: $line');
      }
    }
    expect(offenders, isEmpty);
  });

  test('el pubspec del core sólo depende de paquetes de Dart puro', () {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final start = lines.indexWhere((l) => l.trim() == 'dependencies:');
    final declared = lines.skip(start + 1).takeWhile((l) => l.startsWith('  ')).map((l) => l.trim().split(':').first).toSet();
    expect(declared, {'bloc', 'equatable', 'uuid'}, reason: 'añadir una dependencia al core exige revisar que sea Dart puro');
    expect(lines.any((l) => l.contains('sdk: flutter')), isFalse);
  });
}
