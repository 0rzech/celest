import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:logging/logging.dart';
import 'package:observability/observability.dart';
import 'package:test/test.dart';

void main() {
  group('StructuredLogger', () {
    late Logger baseLogger;
    late StructuredLogger logger;
    late List<LogRecord> records;
    late StreamSubscription<LogRecord> subscription;
    late bool originalHierarchy;

    setUp(() {
      originalHierarchy = hierarchicalLoggingEnabled;
      hierarchicalLoggingEnabled = true;
      Logger.root.level = Level.ALL;

      baseLogger = Logger('observability.logging_test');
      baseLogger.level = Level.ALL;

      logger = StructuredLogger.withLogger(
        baseLogger,
        defaults: {'component': 'auth'},
      );
      records = <LogRecord>[];
      subscription = baseLogger.onRecord.listen(records.add);
    });

    tearDown(() async {
      await subscription.cancel();
      hierarchicalLoggingEnabled = originalHierarchy;
    });

    test('emits json payloads merged with defaults', () {
      logger.info(
        'celest.auth.login',
        data: {'userId': 'usr_123', 'session': null, 'success': true},
        message: 'user authenticated',
      );

      check(records.length).equals(1);
      final LogRecord record = records.single;
      check(record.level).equals(Level.INFO);
      final String jsonMessage = record.message;
      final payload = jsonDecode(jsonMessage) as Map<String, Object?>;
      check(payload).deepEquals({
        'event': 'celest.auth.login',
        'component': 'auth',
        'userId': 'usr_123',
        'success': true,
        'message': 'user authenticated',
      });
    });

    test('withFields extends defaults without mutating parent', () {
      final StructuredLogger child = logger.withFields({'operation': 'verify'});

      child.debug('celest.corks.verify');
      logger.debug('celest.auth.parent');

      check(records.length).equals(2);
      final String firstMessage = records.first.message;
      final String secondMessage = records.last.message;
      final first = jsonDecode(firstMessage) as Map<String, Object?>;
      final second = jsonDecode(secondMessage) as Map<String, Object?>;
      check(
        first,
      ).has((map) => map['event'], 'event').equals('celest.corks.verify');
      check(first).has((map) => map['operation'], 'operation').equals('verify');
      check(first).has((map) => map['component'], 'component').equals('auth');
      check(
        second,
      ).has((map) => map['event'], 'event').equals('celest.auth.parent');
      check(second)
          .has((map) => map.containsKey('operation'), 'operation present')
          .isFalse();
    });

    test('propagates error metadata', () {
      final error = StateError('boom');
      final StackTrace stack = StackTrace.current;

      logger.error('celest.auth.failure', error: error, stackTrace: stack);

      check(records.length).equals(1);
      final LogRecord record = records.single;
      check(record.level).equals(Level.SEVERE);
      check(record.error).identicalTo(error);
      check(record.stackTrace).equals(stack);
    });
  });
}
