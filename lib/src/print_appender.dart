import 'package:logging/logging.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/internal/print_appender_default.dart'
    if (dart.library.io) 'package:logging_appenders/src/'
        'internal/print_appender_io.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';

/// Appender which outputs all log records using the given formatter to
/// stdout using `print()`.
class PrintAppender extends BaseLogAppender {
  PrintAppender({LogRecordFormatter? formatter})
      : super(formatter ?? defaultLogRecordFormatter());

  /// Will setup the root logger with the given level and appends
  /// a new PrintAppender to it.
  ///
  /// Will also remove all previously registered listeners on the root logger.
  ///
  /// If [stderrLevel] is set in dart:io, will log everything at and above
  /// this level to stderr instead of stdout.
  static PrintAppender setupLogging({
    Level level = Level.ALL,
    Level stderrLevel = Level.OFF,
  }) {
    assert(level != null);
    assert(stderrLevel == null || level <= stderrLevel);
    Logger.root.clearListeners();
    Logger.root.level = level;
    return defaultCreatePrintAppender(stderrLevel: stderrLevel)
      ..attachToLogger(Logger.root);
  }

  void Function(Object line)? printer;

  @override
  void handle(LogRecord record) {
    print(formatter.format(record));
  }
}
