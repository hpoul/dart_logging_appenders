import 'dart:async';

import 'package:logging/logging.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:meta/meta.dart';

typedef LogRecordListener = void Function(LogRecord rec);

/// Some global configuration for `logging_appenders` package.
class LoggingAppenders {
  /// Allows changing log level for internal "dummy" loggers
  /// (will always only `print()`)
  static set internalLogLevel(Level? level) =>
      DummyLogger.internalLogLevel = level;
}

/// Base class for log appenders to handle subscriptions to specific
/// loggers as well as [dispose]ing them.
abstract class BaseLogAppender {
  BaseLogAppender(LogRecordFormatter? formatter)
      : formatter = formatter ?? const DefaultLogRecordFormatter();

  final LogRecordFormatter formatter;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  @protected
  @visibleForTesting
  void handle(LogRecord record);

  @protected
  LogRecordListener logListener() => (LogRecord record) => handle(record);

  void attachToLogger(Logger logger) {
    _subscriptions.add(logger.onRecord.listen(logListener()));
  }

  void call(LogRecord record) => handle(record);

  @mustCallSuper
  Future<void> dispose() async {
    await _cancelSubscriptions();
  }

  Future<void> _cancelSubscriptions() async {
    final futures =
        _subscriptions.map((sub) => sub.cancel()).toList(growable: false);
    _subscriptions.clear();
    await Future.wait<dynamic>(futures);
  }
}
