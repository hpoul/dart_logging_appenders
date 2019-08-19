import 'package:logging/logging.dart';

abstract class LogRecordFormatter {
  const LogRecordFormatter();

  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb);

  String format(LogRecord rec) =>
      formatToStringBuffer(rec, StringBuffer()).toString();
}

class DefaultLogRecordFormatter extends LogRecordFormatter {
  const DefaultLogRecordFormatter();

  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) {
    sb.write('${rec.time} ${rec.level.name} '
        '${rec.loggerName} - ${rec.message}');

    if (rec.error != null) {
      sb.write(rec.error);
    }
    // ignore: avoid_as
    final stackTrace = rec.stackTrace ??
        (rec.error is Error ? (rec.error as Error).stackTrace : null);
    if (stackTrace != null) {
      sb.write(stackTrace);
    }
    return sb;
  }
}
