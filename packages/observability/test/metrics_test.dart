import 'dart:collection';

import 'package:checks/checks.dart';
import 'package:clock/clock.dart';
import 'package:observability/observability.dart';
import 'package:test/test.dart';

void main() {
  group('NoOpMetricRecorder', () {
    test('returns reusable singleton instruments', () {
      const recorder = NoOpMetricRecorder();

      final Counter counterA = recorder.counter('alpha');
      final Counter counterB = recorder.counter('beta');
      final Histogram histogramA = recorder.histogram('latency');
      final Histogram histogramB = recorder.histogram('size');

      check(counterA).identicalTo(counterB);
      check(histogramA).identicalTo(histogramB);
    });

    test('ignores counter and histogram updates without throwing', () {
      const recorder = NoOpMetricRecorder();
      final Counter counter = recorder.counter('ignored');
      final Histogram histogram = recorder.histogram('ignored');

      expect(
        () => counter.add(1, attributes: {'key': 'value'}),
        returnsNormally,
      );
      expect(
        () => histogram.record(42, attributes: {'key': 'value'}),
        returnsNormally,
      );
    });
  });

  group('recordLatency', () {
    test('records elapsed milliseconds with attributes', () async {
      final histogram = _RecordingHistogram();
      final base = DateTime.utc(2025, 1, 1, 0, 0, 0, 0, 0);
      final clock = _FakeClock([
        base,
        base.add(const Duration(milliseconds: 42)),
      ]);

      await withClock(clock, () async {
        await recordLatency(
          histogram: histogram,
          attributes: const {'operation': 'insert'},
          run: () async {},
        );
      });

      check(histogram.records.length).equals(1);
      final _Record record = histogram.records.single;
      check(record.measurement).equals(42);
      check(record.attributes).isNotNull().which(
        (attrs) =>
            attrs.has((map) => map['operation'], 'operation').equals('insert'),
      );
    });

    test('records latency even when run throws', () async {
      final histogram = _RecordingHistogram();
      final base = DateTime.utc(2025, 1, 1, 0, 0, 0, 0, 0);
      final clock = _FakeClock([
        base,
        base.add(const Duration(milliseconds: 7)),
      ]);

      final Future<void> future = withClock(clock, () {
        return recordLatency<void>(
          histogram: histogram,
          run: () async => throw StateError('boom'),
        );
      });

      await expectLater(future, throwsA(isA<StateError>()));
      check(histogram.records.length).equals(1);
      final _Record record = histogram.records.single;
      check(record.measurement).equals(7);
      check(record.attributes).isNull();
    });
  });
}

final class _RecordingHistogram implements Histogram {
  final List<_Record> records = [];

  @override
  void record(num value, {Map<String, String>? attributes}) {
    records.add(_Record(value, attributes));
  }
}

final class _Record {
  _Record(this.measurement, this.attributes);

  final num measurement;
  final Map<String, String>? attributes;
}

final class _FakeClock extends Clock {
  _FakeClock(List<DateTime> instants)
    : _instants = Queue.of(instants),
      _last = instants.isNotEmpty ? instants.last : DateTime.now();

  final Queue<DateTime> _instants;
  DateTime _last;

  @override
  DateTime now() {
    if (_instants.isEmpty) {
      return _last;
    }
    return _last = _instants.removeFirst();
  }
}
