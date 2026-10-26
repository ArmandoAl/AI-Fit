import 'package:aifit/features/outfit/domain/outfit_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all try-on positions use the Seedream default', () {
    expect(defaultTryOnProvider, 'seedream');
    expect(List.generate(3, tryOnProviderForPosition), [
      'seedream',
      'seedream',
      'seedream',
    ]);
    expect(tryOnProviderForPosition(99), 'seedream');
  });
}
