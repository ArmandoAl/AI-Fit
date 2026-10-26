import 'package:aifit_core/features/outfit/domain/outfit_models.dart';
import 'package:test/test.dart';

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
