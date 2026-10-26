/// Runs async tasks over a list with a bounded concurrency pool.
class ConcurrentTaskPool {
  ConcurrentTaskPool._();

  static const int defaultConcurrency = 5;

  /// Maps each [items] entry through [task], at most [concurrency] at a time.
  /// Failed tasks yield `null` at that index.
  static Future<List<T?>> mapConcurrent<T, I>(
    List<I> items,
    Future<T?> Function(I item) task, {
    int concurrency = defaultConcurrency,
  }) async {
    if (items.isEmpty) return [];

    final results = List<T?>.filled(items.length, null);
    var nextIndex = 0;
    final poolSize = concurrency.clamp(1, items.length);

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex++;
        if (index >= items.length) return;
        try {
          results[index] = await task(items[index]);
        } catch (_) {
          results[index] = null;
        }
      }
    }

    await Future.wait(List.generate(poolSize, (_) => worker()));
    return results;
  }
}
