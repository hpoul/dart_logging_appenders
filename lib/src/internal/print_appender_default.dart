import 'package:logging/logging.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:logging_appenders/src/print_appender.dart';

LogRecordFormatter defaultLogRecordFormatter() =>
    const DefaultLogRecordFormatter();

PrintAppender defaultCreatePrintAppender({
  LogRecordFormatter? formatter,
  Level? stderrLevel,
}) =>
    PrintAppender(formatter: formatter);
