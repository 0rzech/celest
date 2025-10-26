import 'package:observability/src/metrics.dart';

/// Lightweight wrapper that produces a [Histogram] from a [MetricRecorder] and
/// offers ergonomic helpers for recording numeric values.
///
/// ```dart
/// final recorder = obtainMetricRecorder();
/// final latency = StructuredHistogram(
///   recorder: recorder,
///   name: 'worker_latency_ms',
///   description: 'Latency grouped by route.',
/// );
///
/// latency.record(42, attributes: {'route': '/hello'});
/// latency.recordDuration(const Duration(milliseconds: 12));
/// ```
class StructuredHistogram {
  /// Creates a histogram named [name] using the provided [recorder].
  StructuredHistogram({
    required MetricRecorder recorder,
    required String name,
    String? description,
  }) : _histogram = recorder.histogram(name, description: description);

  final Histogram _histogram;

  /// Records a numeric [value] with optional dimension attributes.
  void record(num value, {Map<String, String>? attributes}) {
    _histogram.record(value, attributes: attributes);
  }

  /// Records the provided [duration] expressed in milliseconds.
  void recordDuration(Duration duration, {Map<String, String>? attributes}) {
    record(duration.inMilliseconds, attributes: attributes);
  }
}
