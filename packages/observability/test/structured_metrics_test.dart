import 'package:checks/checks.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:observability/observability.dart';
import 'package:test/test.dart';

void main() {
  group('StructuredCounter', () {
    test('increments underlying counter', () {
      final recorder = _FakeMetricRecorder();
      final counter = StructuredCounter(
        recorder: recorder,
        name: 'test_counter',
      );

      counter.increment(attributes: {'result': 'ok'});
      counter.add(3, attributes: {'result': 'retry'});

      check(recorder.counterCalls.length).equals(2);
      check(
        recorder.counterCalls[0],
      ).equals(const _Call('test_counter', 1, {'result': 'ok'}));
      check(
        recorder.counterCalls[1],
      ).equals(const _Call('test_counter', 3, {'result': 'retry'}));
    });
  });

  group('StructuredHistogram', () {
    test('records numeric values', () {
      final recorder = _FakeMetricRecorder();
      final histogram = StructuredHistogram(
        recorder: recorder,
        name: 'latency',
      );

      histogram.record(12.5, attributes: {'route': 'verify'});
      histogram.recordDuration(
        const Duration(milliseconds: 42),
        attributes: {'route': 'verify'},
      );

      check(recorder.histogramCalls.length).equals(2);
      check(
        recorder.histogramCalls[0],
      ).equals(const _Call('latency', 12.5, {'route': 'verify'}));
      check(
        recorder.histogramCalls[1],
      ).equals(const _Call('latency', 42, {'route': 'verify'}));
    });
  });
}

@immutable
class _Call {
  const _Call(this.name, this.value, this.attributes);

  final String name;
  final num value;
  final Map<String, String>? attributes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _Call &&
        other.name == name &&
        other.value == value &&
        const MapEquality<String, String>().equals(
          other.attributes,
          attributes,
        );
  }

  @override
  int get hashCode =>
      Object.hash(name, value, Object.hashAll(attributes?.entries ?? []));
}

final class _FakeMetricRecorder implements MetricRecorder {
  final List<_Call> counterCalls = [];
  final List<_Call> histogramCalls = [];

  @override
  Counter counter(String name, {String? description}) {
    return _FakeCounter(recorder: this, name: name);
  }

  @override
  Histogram histogram(String name, {String? description}) {
    return _FakeHistogram(recorder: this, name: name);
  }
}

final class _FakeCounter implements Counter {
  _FakeCounter({required this.recorder, required this.name});

  final _FakeMetricRecorder recorder;
  final String name;

  @override
  void add(num value, {Map<String, String>? attributes}) {
    recorder.counterCalls.add(_Call(name, value, attributes));
  }
}

final class _FakeHistogram implements Histogram {
  _FakeHistogram({required this.recorder, required this.name});

  final _FakeMetricRecorder recorder;
  final String name;

  @override
  void record(num value, {Map<String, String>? attributes}) {
    recorder.histogramCalls.add(_Call(name, value, attributes));
  }
}
