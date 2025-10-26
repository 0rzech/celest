// ignore_for_file: avoid_print, omit_obvious_local_variable_types

import 'dart:async';

import 'package:observability/observability.dart';

/// Simple example that wires up custom metric and tracing recorders and emits
/// a few demo signals. In a production setting these recorders would forward
/// data to systems such as OpenTelemetry, Prometheus, or Honeycomb.
Future<void> main() async {
  // Install global registries so framework code can locate the recorders.
  GlobalMetrics.install(MetricsRegistry(recorder: _PrintMetricRecorder()));
  GlobalTracer.install(TracerRegistry(tracer: _PrintTracer()));

  final MetricRecorder recorder = GlobalMetrics.instance.recorder;

  // Create structured helpers that attach consistent attributes.
  final StructuredCounter requestCounter = StructuredCounter(
    recorder: recorder,
    name: 'example_requests_total',
    description: 'Number of demo requests by method.',
  );

  final StructuredCounter cacheCounter = StructuredCounter(
    recorder: recorder,
    name: 'example_cache_outcome_total',
    description: 'Cache results grouped by outcome.',
  );

  final Histogram latencyHistogram = recorder.histogram(
    'example_request_latency_ms',
    description: 'Latency for demo request handling in milliseconds.',
  );

  final Tracer tracer = GlobalTracer.instance.tracer;

  // Emit observability signals around some fake work.
  await tracer.trace<void>(
    name: 'example.request',
    attributes: {'route': '/hello', 'method': 'GET'},
    run: (Span span) async {
      requestCounter.increment(attributes: {'method': 'GET'});

      await recordLatency(
        histogram: latencyHistogram,
        attributes: {'route': '/hello'},
        run: () async {
          span.addEvent('work.started');
          await Future<void>.delayed(const Duration(milliseconds: 12));
          span.addEvent('work.finished');
        },
      );

      cacheCounter.increment(attributes: {'outcome': 'miss'});

      span.setStatus(SpanStatus.ok);
    },
  );
}

class _PrintMetricRecorder implements MetricRecorder {
  @override
  Counter counter(String name, {String? description}) {
    return _PrintCounter(name, description: description);
  }

  @override
  Histogram histogram(String name, {String? description}) {
    return _PrintHistogram(name, description: description);
  }
}

class _PrintCounter implements Counter {
  _PrintCounter(this.name, {this.description});

  final String name;
  final String? description;

  @override
  void add(num value, {Map<String, String>? attributes}) {
    print(
      'counter<$name>${description != null ? ' ($description)' : ''}: '
      'value=$value attributes=$attributes',
    );
  }
}

class _PrintHistogram implements Histogram {
  _PrintHistogram(this.name, {this.description});

  final String name;
  final String? description;

  @override
  void record(num value, {Map<String, String>? attributes}) {
    print(
      'histogram<$name>${description != null ? ' ($description)' : ''}: '
      'value=$value attributes=$attributes',
    );
  }
}

class _PrintTracer extends Tracer {
  @override
  Span startSpan(
    String name, {
    SpanContext? parent,
    Map<String, Object?>? attributes,
  }) {
    print('span<$name> start attributes=$attributes');
    return _PrintSpan(name, parent: parent);
  }
}

class _PrintSpan implements Span {
  _PrintSpan(this.name, {SpanContext? parent}) : _context = _derive(parent);

  final String name;
  final SpanContext _context;
  SpanStatus _status = SpanStatus.unset;

  @override
  SpanContext get context => _context;

  @override
  void addEvent(String eventName, {Map<String, Object?>? attributes}) {
    print('span<$name> event=$eventName attributes=$attributes');
  }

  @override
  void end({SpanStatus status = SpanStatus.unset}) {
    _status = status == SpanStatus.unset ? _status : status;
    print('span<$name> end status=$_status');
  }

  @override
  void recordError(Object error, StackTrace stackTrace) {
    print('span<$name> error=$error stackTrace=$stackTrace');
    _status = SpanStatus.error;
  }

  @override
  void setAttribute(String key, Object? value) {
    print('span<$name> attr $key=$value');
  }

  @override
  void setStatus(SpanStatus status, {String? description}) {
    _status = status;
    print('span<$name> status=$status description=$description');
  }

  static SpanContext _derive(SpanContext? parent) {
    final String traceId = parent?.traceId ?? 'example-trace';
    final String spanId = DateTime.now().microsecondsSinceEpoch.toString();
    return SpanContext(traceId: traceId, spanId: spanId);
  }
}
