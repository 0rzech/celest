import 'dart:async';

import 'package:checks/checks.dart';
import 'package:observability/observability.dart';
import 'package:test/test.dart';

void main() {
  group('Tracer.trace', () {
    test('completes span with ok status on success', () async {
      final tracer = _RecordingTracer();
      await tracer.trace<void>(
        name: 'success',
        run: (span) async {
          span.setAttribute('key', 'value');
        },
      );

      final List<_RecordingSpan> spans = tracer.completedSpans;
      check(spans.length).equals(1);
      final _RecordingSpan span = spans.single;
      check(span.name).equals('success');
      check(span.status).equals(SpanStatus.ok);
      check(span.attributes['key']).equals('value');
    });

    test('records error and marks span error on exception', () async {
      final tracer = _RecordingTracer();
      final error = StateError('boom');

      await expectLater(
        () => tracer.trace<void>(
          name: 'failure',
          run: (_) => Future<void>.error(error, StackTrace.current),
        ),
        throwsA(isA<StateError>()),
      );

      final List<_RecordingSpan> spans = tracer.completedSpans;
      check(spans.length).equals(1);
      final _RecordingSpan span = spans.single;
      check(span.name).equals('failure');
      check(span.status).equals(SpanStatus.error);
      check(
        span.errors,
      ).has((errors) => errors.length, 'error count').equals(1);
      check(span.errors.single.$1).equals(error);
    });
  });
}

final class _RecordingTracer extends Tracer {
  final List<_RecordingSpan> _spans = [];
  final List<_RecordingSpan> completedSpans = [];

  @override
  Span startSpan(
    String name, {
    SpanContext? parent,
    Map<String, Object?>? attributes,
  }) {
    final span = _RecordingSpan(
      name,
      parent: parent,
      initialAttributes: attributes,
      onComplete: completedSpans.add,
    );
    _spans.add(span);
    return span;
  }
}

final class _RecordingSpan implements Span {
  _RecordingSpan(
    this.name, {
    SpanContext? parent,
    Map<String, Object?>? initialAttributes,
    required void Function(_RecordingSpan span) onComplete,
  }) : _context = _RecordingSpan._deriveContext(parent),
       _onComplete = onComplete {
    if (initialAttributes != null) {
      _attributes.addAll(initialAttributes);
    }
  }

  static int _nextId = 0;

  static SpanContext _deriveContext(SpanContext? parent) {
    final String traceId = parent?.traceId ?? 'trace-${_nextId++}';
    final spanId = 'span-${_nextId++}';
    return SpanContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: parent?.traceFlags,
    );
  }

  final String name;
  final Map<String, Object?> _attributes = {};
  final List<(Object, StackTrace)> errors = [];
  final void Function(_RecordingSpan span) _onComplete;

  SpanStatus _status = SpanStatus.unset;
  String? statusDescription;
  bool _ended = false;

  @override
  SpanContext get context => _context;
  final SpanContext _context;

  Map<String, Object?> get attributes => _attributes;
  SpanStatus get status => switch (_status) {
    SpanStatus.unset => SpanStatus.ok,
    _ => _status,
  };

  @override
  void addEvent(String name, {Map<String, Object?>? attributes}) {
    // Events are not recorded for these tests.
  }

  @override
  void end({SpanStatus status = SpanStatus.unset}) {
    if (_ended) {
      return;
    }
    if (status != SpanStatus.unset) {
      _status = status;
    }
    _ended = true;
    _onComplete(this);
  }

  @override
  void recordError(Object error, StackTrace stackTrace) {
    errors.add((error, stackTrace));
    _status = SpanStatus.error;
  }

  @override
  void setAttribute(String key, Object? value) {
    _attributes[key] = value;
  }

  @override
  void setStatus(SpanStatus status, {String? description}) {
    _status = status;
    statusDescription = description;
  }
}
