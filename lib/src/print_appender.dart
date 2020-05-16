import 'package:logging/logging.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart'
    if (dart.library.io) 'package:logging_appenders/src/logrecord_formatter_io.dart';

import 'internal/print_appender_default.dart';

/// Appender which outputs all log records using the given formatter to
/// stdout using `print()`.
class PrintAppender extends BaseLogAppender {
  PrintAppender({LogRecordFormatter formatter})
      : super(formatter ?? defaultLogRecordFormatter());

  /// Will setup the root logger with the given level and appends
  /// a new PrintAppender to it.
  static PrintAppender setupLogging({Level level = Level.ALL}) {
    Logger.root.clearListeners();
    Logger.root.level = Level.ALL;
    return PrintAppender()..attachToLogger(Logger.root);
  }

  void Function(Object line) printer;

  @override
  void handle(LogRecord record) {
    print(formatter.format(record));
  }
}
