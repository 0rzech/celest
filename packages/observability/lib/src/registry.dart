import 'package:observability/src/metrics.dart';
import 'package:observability/src/tracing.dart';

/// Registry providing access to metric instruments within an application.
///
/// Most Celest services install a shared instance during start-up:
///
/// ```dart
/// final recorder = PrometheusRecorder(/* config */);
/// MetricsRegistry globalRegistry = MetricsRegistry(recorder: recorder);
/// GlobalMetrics.install(globalRegistry);
/// ```
///
/// The registry defaults to a [NoOpMetricRecorder] so metric calls remain safe
/// when no recorder is installed.
class MetricsRegistry {
  /// Creates a registry backed by [recorder], defaulting to a no-op recorder
  /// when none is supplied.
  MetricsRegistry({MetricRecorder? recorder})
    : _recorder = recorder ?? const NoOpMetricRecorder();

  final MetricRecorder _recorder;

  /// Provides the metric recorder to call sites.
  MetricRecorder get recorder => _recorder;
}

/// Global accessor for applications that prefer a singleton registry.
///
/// ```dart
/// GlobalMetrics.install(MetricsRegistry(recorder: myRecorder));
/// final MetricRecorder recorder = GlobalMetrics.instance.recorder;
/// ```
class GlobalMetrics {
  const GlobalMetrics._();

  static MetricsRegistry _instance = MetricsRegistry();

  /// Returns the current global registry.
  static MetricsRegistry get instance => _instance;

  /// Overrides the global registry. Mainly used in tests.
  // ignore: use_setters_to_change_properties
  static void install(MetricsRegistry registry) {
    _instance = registry;
  }
}

/// Registry providing access to tracer implementations.
///
/// ```dart
/// final tracer = OpenTelemetryTracer();
/// GlobalTracer.install(TracerRegistry(tracer: tracer));
/// ```
class TracerRegistry {
  /// Creates a registry backed by [tracer], defaulting to a [NoOpTracer] when
  /// no tracer is supplied.
  TracerRegistry({Tracer? tracer}) : _tracer = tracer ?? NoOpTracer();

  final Tracer _tracer;

  /// Provides the tracer to call sites.
  Tracer get tracer => _tracer;
}

/// Global accessor for tracer usage when dependency injection is unavailable.
class GlobalTracer {
  const GlobalTracer._();

  static TracerRegistry _instance = TracerRegistry();

  /// Returns the current global tracing registry.
  static TracerRegistry get instance => _instance;

  /// Overrides the global tracing registry.
  // ignore: use_setters_to_change_properties
  static void install(TracerRegistry registry) {
    _instance = registry;
  }
}
