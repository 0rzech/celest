import 'package:observability/observability.dart';
import 'package:test/test.dart';

class _RecordingCounter implements Counter {
  final List<num> values = [];
  final List<Map<String, String>?> attributes = [];

  @override
  void add(num value, {Map<String, String>? attributes}) {
    values.add(value);
    this.attributes.add(attributes);
  }
}

void main() {
  group('recordLatency', () {
    test('records duration in milliseconds', () async {
      final counter = _RecordingCounter();
      final histogram = _HistogramCounter(counter);

      await recordLatency(histogram: histogram, run: () async {});

      expect(counter.values, isNotEmpty);
      expect(counter.values.single, isA<num>());
    });
  });
}

class _HistogramCounter implements Histogram {
  _HistogramCounter(this._counter);

  final _RecordingCounter _counter;

  @override
  void record(num value, {Map<String, String>? attributes}) {
    _counter.add(value, attributes: attributes);
  }
}
