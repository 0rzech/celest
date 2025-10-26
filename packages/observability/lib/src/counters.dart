import 'package:observability/src/metrics.dart';

/// A convenience wrapper around [Counter] that standardises metric creation and
/// exposes expressive helper methods.
///
/// Typical usage installs a [MetricRecorder] during service start-up and then
/// creates a `StructuredCounter` to emit
/// instrumented data:
///
/// ```dart
/// final recorder = obtainMetricRecorder();
/// final counter = StructuredCounter(
///   recorder: recorder,
///   name: 'http_requests_total',
///   description: 'Requests grouped by method.',
/// );
///
/// counter.increment(attributes: {'method': 'GET'});
/// counter.add(5, attributes: {'method': 'POST'});
/// ```
class StructuredCounter {
  /// Creates a counter named [name] using the provided [recorder].
  StructuredCounter({
    required MetricRecorder recorder,
    required String name,
    String? description,
  }) : _counter = recorder.counter(name, description: description);

  final Counter _counter;

  /// Increments the counter by 1 with optional [attributes].
  void increment({Map<String, String>? attributes}) =>
      _counter.add(1, attributes: attributes);

  /// Adds an arbitrary [value] to the counter with optional [attributes].
  void add(num value, {Map<String, String>? attributes}) =>
      _counter.add(value, attributes: attributes);
}
