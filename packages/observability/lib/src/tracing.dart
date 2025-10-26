import 'dart:async';

/// Represents the identifying information for a span.
class SpanContext {
  /// Creates a span context with optional identifiers and trace metadata.
  const SpanContext({
    this.traceId,
    this.spanId,
    this.traceFlags,
    this.traceState,
  });

  /// The trace ID associated with the span, if available.
  final String? traceId;

  /// The span ID associated with the span, if available.
  final String? spanId;

  /// Trace sampling flags encoded as an integer, if provided.
  final int? traceFlags;

  /// Vendor-specific trace state for propagating baggage.
  final Map<String, String>? traceState;
}

/// Standard span statuses mirroring OpenTelemetry semantics.
enum SpanStatus {
  /// Status has not been set and should inherit defaults.
  unset,

  /// Span completed successfully without errors.
  ok,

  /// Span encountered an error during execution.
  error,
}

/// A span represents an active unit of work in a trace.
abstract class Span {
  /// Identifies this span for propagating child context.
  SpanContext get context;

  /// Associates the provided [key] and [value] with the span.
  void setAttribute(String key, Object? value);

  /// Records a structured event on the span timeline.
  void addEvent(String name, {Map<String, Object?>? attributes});

  /// Records an exception that occurred while the span was active.
  void recordError(Object error, StackTrace stackTrace);

  /// Sets the final status for the span prior to completion.
  void setStatus(SpanStatus status, {String? description});

  /// Completes the span and notifies downstream exporters.
  void end({SpanStatus status = SpanStatus.unset});
}

/// Contracts for creating spans against an underlying tracer implementation.
abstract class Tracer {
  /// Begins a new span.
  Span startSpan(
    String name, {
    SpanContext? parent,
    Map<String, Object?>? attributes,
  });

  /// Helper for executing [run] within a span and managing its lifecycle.
  ///
  /// ```dart
  /// final tracer = obtainTracer();
  /// await tracer.trace<void>(
  ///   name: 'db.query',
  ///   attributes: {'statement': 'SELECT 1'},
  ///   run: (span) async {
  ///     try {
  ///       await database.query('SELECT 1');
  ///       span.setStatus(SpanStatus.ok);
  ///     } on Object catch (error, stack) {
  ///       span.recordError(error, stack);
  ///       span.setStatus(SpanStatus.error);
  ///       rethrow;
  ///     }
  ///   },
  /// );
  /// ```
  Future<T> trace<T>({
    required String name,
    SpanContext? parent,
    Map<String, Object?>? attributes,
    required Future<T> Function(Span span) run,
  }) async {
    final Span span = startSpan(name, parent: parent, attributes: attributes);
    try {
      final T result = await run(span);
      span.end();
      return result;
    } on Object catch (error, stackTrace) {
      span.recordError(error, stackTrace);
      span.end(status: SpanStatus.error);
      rethrow;
    }
  }
}

/// A no-op span used when tracing is disabled.
class NoOpSpan implements Span {
  /// Creates a span that discards telemetry signals.
  const NoOpSpan();

  static const SpanContext _context = SpanContext();

  @override
  void addEvent(String name, {Map<String, Object?>? attributes}) {}

  @override
  SpanContext get context => _context;

  @override
  void end({SpanStatus status = SpanStatus.unset}) {}

  @override
  void recordError(Object error, StackTrace stackTrace) {}

  @override
  void setAttribute(String key, Object? value) {}

  @override
  void setStatus(SpanStatus status, {String? description}) {}
}

/// A no-op tracer used when tracing is disabled.
class NoOpTracer extends Tracer {
  /// Creates a tracer that drops all span data.
  NoOpTracer();

  static const NoOpSpan _span = NoOpSpan();

  /// @nodoc
  @override
  Span startSpan(
    String name, {
    SpanContext? parent,
    Map<String, Object?>? attributes,
  }) {
    return _span;
  }
}
