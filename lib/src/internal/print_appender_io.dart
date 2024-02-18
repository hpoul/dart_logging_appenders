import 'dart:io';

import 'package:logging/logging.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:logging_appenders/src/print_appender.dart';

LogRecordFormatter defaultLogRecordFormatter() => stdout.supportsAnsiEscapes
    ? const ColorFormatter()
    : const DefaultLogRecordFormatter();

PrintAppender defaultCreatePrintAppender({Level? stderrLevel}) =>
    IoPrintAppender(stderrLevel: stderrLevel);

class IoPrintAppender extends PrintAppender {
  IoPrintAppender({
    super.formatter,
    this.stderrLevel,
  });

  final Level? stderrLevel;

  @override
  void handle(LogRecord record) {
    if (stderrLevel != null && record.level >= stderrLevel!) {
      stderr.writeln(formatter.format(record));
    } else {
      super.handle(record);
    }
  }
}
