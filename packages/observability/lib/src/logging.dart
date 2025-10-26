import 'dart:convert';

import 'package:logging/logging.dart';

/// Emits structured JSON logs via `package:logging`.
class StructuredLogger {
  StructuredLogger(String name, {Map<String, Object?>? defaults})
    : this._(Logger(name), _sanitize(defaults));

  StructuredLogger.withLogger(Logger logger, {Map<String, Object?>? defaults})
    : this._(logger, _sanitize(defaults));

  StructuredLogger._(this._logger, this._defaults);

  final Logger _logger;
  final Map<String, Object?> _defaults;

  /// Access to the underlying [Logger] for advanced configuration.
  Logger get logger => _logger;

  /// Returns a new logger that always includes [fields] in each payload.
  StructuredLogger withFields(Map<String, Object?> fields) {
    if (fields.isEmpty) {
      return StructuredLogger._(_logger, _defaults);
    }
    final merged = <String, Object?>{..._defaults};
    for (final MapEntry<String, Object?> entry in fields.entries) {
      final Object? value = entry.value;
      if (value == null) {
        merged.remove(entry.key);
        continue;
      }
      merged[entry.key] = value;
    }
    return StructuredLogger._(_logger, Map.unmodifiable(merged));
  }

  /// Emits a structured log at the provided [level].
  void emit(
    Level level, {
    required String event,
    Map<String, Object?>? data,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_logger.isLoggable(level)) {
      return;
    }
    final Map<String, Object?> payload = _payload(
      event: event,
      data: data,
      message: message,
    );
    _logger.log(level, jsonEncode(payload), error, stackTrace);
  }

  /// Emits a debug-level structured log.
  void debug(
    String event, {
    Map<String, Object?>? data,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  }) => emit(
    Level.FINE,
    event: event,
    data: data,
    message: message,
    error: error,
    stackTrace: stackTrace,
  );

  /// Emits an info-level structured log.
  void info(
    String event, {
    Map<String, Object?>? data,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  }) => emit(
    Level.INFO,
    event: event,
    data: data,
    message: message,
    error: error,
    stackTrace: stackTrace,
  );

  /// Emits a warning-level structured log.
  void warning(
    String event, {
    Map<String, Object?>? data,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  }) => emit(
    Level.WARNING,
    event: event,
    data: data,
    message: message,
    error: error,
    stackTrace: stackTrace,
  );

  /// Emits an error-level structured log.
  void error(
    String event, {
    Map<String, Object?>? data,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  }) => emit(
    Level.SEVERE,
    event: event,
    data: data,
    message: message,
    error: error,
    stackTrace: stackTrace,
  );

  Map<String, Object?> _payload({
    required String event,
    Map<String, Object?>? data,
    String? message,
  }) {
    final payload = <String, Object?>{..._defaults};
    if (data != null && data.isNotEmpty) {
      for (final MapEntry<String, Object?> entry in data.entries) {
        final Object? value = entry.value;
        if (value == null) {
          continue;
        }
        payload[entry.key] = value;
      }
    }
    if (message != null) {
      payload['message'] = message;
    }
    payload['event'] = event;
    return payload;
  }

  static Map<String, Object?> _sanitize(Map<String, Object?>? source) {
    if (source == null || source.isEmpty) {
      return const {};
    }
    final copy = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in source.entries) {
      final Object? value = entry.value;
      if (value != null) {
        copy[entry.key] = value;
      }
    }
    return Map.unmodifiable(copy);
  }
}
