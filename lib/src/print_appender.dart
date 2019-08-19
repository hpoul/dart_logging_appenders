import 'package:logging/logging.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';

/// Appender which outputs all log records using the given formatter to
/// stdout using `print()`.
class PrintAppender extends BaseLogAppender {
  PrintAppender({LogRecordFormatter formatter}) : super(formatter);

  @override
  void handle(LogRecord record) {
    print(formatter.format(record));
  }
}
