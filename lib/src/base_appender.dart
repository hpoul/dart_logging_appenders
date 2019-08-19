import 'package:logging/logging.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:meta/meta.dart';

typedef LogRecordListener = void Function(LogRecord rec);

abstract class BaseLogAppender {
  const BaseLogAppender(LogRecordFormatter formatter)
      : formatter = formatter ?? const DefaultLogRecordFormatter();

  final LogRecordFormatter formatter;

  @protected
  void handle(LogRecord record);

  LogRecordListener logListener() => (LogRecord record) => handle(record);

  void call(LogRecord record) => handle(record);
}
