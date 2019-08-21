import 'dart:io';

import 'package:logging/logging.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';

/// Appender which outputs all log records using the given formatter to
/// stdout using `print()`.
class PrintAppender extends BaseLogAppender {
  PrintAppender({LogRecordFormatter formatter})
      : super(formatter ??
            (stdout.supportsAnsiEscapes
                ? const ColorFormatter()
                : const DefaultLogRecordFormatter()));

  void Function(Object line) printer;

  @override
  void handle(LogRecord record) {
    print(formatter.format(record));
  }
}
