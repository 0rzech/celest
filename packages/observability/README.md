## Observability

Utilities for instrumenting Celest services with structured metrics and
lightweight tracing primitives. The package is backend agnostic; plug in your
preferred recorder or tracer implementation and forward data to systems such as
Prometheus, OpenTelemetry, or Honeycomb.

## Features

- Thin abstractions for counters and histograms with structured attribute maps.
- Global registries (`GlobalMetrics`, `GlobalTracer`) for late-bound DI wiring.
- Helper APIs for measuring latency and running traced closures.

## Getting started

Add the dependency to your `pubspec.yaml` (most Celest repositories already do
this):

```yaml
dependencies:
  observability:
    path: ../../packages/observability
```

Install your recorder/tracer early during service start-up:

```dart
Future<void> bootstrap() async {
  final recorder = PrometheusRecorder(/* config */);
  GlobalMetrics.install(MetricsRegistry(recorder: recorder));  
  
  final tracer = OpenTelemetryTracer(/* config */);
  GlobalTracer.install(TracerRegistry(tracer: tracer));
  }
```

## Usage

Create structured helpers when emitting metrics:

```dart
final StructuredCounter requestCounter = StructuredCounter(
  recorder: GlobalMetrics.instance.recorder,
  name: 'http_requests_total',
  description: 'Requests grouped by method.',
);

requestCounter.increment(attributes: {'method': 'GET'});
```

Measure latency without hand-rolled stopwatches:

```dart
final histogram = GlobalMetrics.instance.recorder.histogram(
  'db_latency_ms',
  description: 'Database round-trip latency in milliseconds.',
);

await recordLatency(
  histogram: histogram,
  attributes: {'operation': 'insert'},
  run: () async => await db.insert(row),
);
```

Wrap business logic in spans to collect trace data:

```dart
await GlobalTracer.instance.tracer.trace<void>(
  name: 'orders.create',
  attributes: {'route': '/v1/orders'},
  run: (span) async {
  	span.addEvent('validation.start');
  	await orderValidator.validate(payload);
  	span.addEvent('validation.complete');
  	span.setStatus(SpanStatus.ok);
  },
);
```

## Example

A runnable example that prints metrics and spans to stdout lives under
[`example/observability_example.dart`](example/observability_example.dart).

## Contributing

File issues and PRs in the main [celest](https://github.com/celest-dev/celest)
repository. Please include relevant logs or traces when reporting
observability-related bugs.
