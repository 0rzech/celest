import 'package:clock/clock.dart';

/// An abstract counter supporting monotonically increasing values.
abstract class Counter {
  /// Increments the counter by [value].
  void add(num value, {Map<String, String>? attributes});
}

/// An abstract histogram for recording duration or size measurements.
abstract class Histogram {
  /// Records a single [value] observation.
  void record(num value, {Map<String, String>? attributes});
}

/// Abstraction for emitting metrics without binding to a concrete backend.
///
/// Applications usually access a [MetricRecorder] via service wiring or
/// dependency injection. The recorder is then responsible for creating counters
/// and histograms that stream data to the chosen metrics system.
///
/// ```dart
/// final recorder = obtainMetricRecorder();
/// final requests = recorder.counter('http_requests_total');
/// requests.add(1, attributes: {'method': 'GET'});
/// ```
abstract class MetricRecorder {
  /// Returns a counter with the provided [name] and optional [description].
  Counter counter(String name, {String? description});

  /// Returns a histogram with the provided [name] and optional [description].
  Histogram histogram(String name, {String? description});
}

/// A no-op implementation used in tests or when metrics are disabled.
class NoOpMetricRecorder implements MetricRecorder {
  /// Creates a recorder that discards all metric updates.
  const NoOpMetricRecorder();

  /// Returns a [Counter] implementation that drops all updates.
  @override
  Counter counter(String name, {String? description}) => const _NoOpCounter();

  /// Returns a [Histogram] implementation that drops all observations.
  @override
  Histogram histogram(String name, {String? description}) =>
      const _NoOpHistogram();
}

/// Counter used by [NoOpMetricRecorder]; silently ignores all updates.
class _NoOpCounter implements Counter {
  const _NoOpCounter();

  @override
  void add(num value, {Map<String, String>? attributes}) {}
}

/// Histogram used by [NoOpMetricRecorder]; silently ignores all updates.
class _NoOpHistogram implements Histogram {
  const _NoOpHistogram();

  @override
  void record(num value, {Map<String, String>? attributes}) {}
}

/// Helper for measuring latency around a closure using a [Histogram].
///
/// The elapsed duration is recorded in milliseconds. Optional [attributes]
/// are attached to the observation.
///
/// ```dart
/// final histogram = obtainMetricRecorder().histogram('db_latency_ms');
///
/// await recordLatency(
///   histogram: histogram,
///   attributes: {'operation': 'insert'},
///   run: () async => await database.insert(row),
/// );
/// ```
Future<T> recordLatency<T>({
  required Histogram histogram,
  required Future<T> Function() run,
  Map<String, String>? attributes,
}) async {
  final DateTime start = clock.now();
  try {
    return await run();
  } finally {
    final Duration elapsed = clock.now().difference(start);
    histogram.record(elapsed.inMicroseconds / 1000, attributes: attributes);
  }
}
