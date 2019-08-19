import 'dart:async';

import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class FakeLogRecordFormatter extends LogRecordFormatter {
  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) =>
      sb..write('msg:${rec.message}');
}

class MockLogRecordFormatter extends Mock implements LogRecordFormatter {
}

void main() {
  test('dummy print logger test', () async {
    final printLog = <String>[];
    final dummyLogger = StreamController<LogRecord>(sync: true);
    final formatter = MockLogRecordFormatter();
    when(formatter.format(any)).thenReturn('mock');
    _overridePrint(printLog, () {
      dummyLogger.stream.listen(PrintAppender(formatter: formatter).logListener());
      dummyLogger.add(LogRecord(Level.INFO, 'foo', 'bar'));
    });

    expect(printLog, equals(['mock']));
    verify(formatter.format(any)).called(1);
  });
}

T _overridePrint<T>(List<String> log, T Function() testFn) {
  final spec = ZoneSpecification(
      print: (_, __, ___, String msg) {
        // Add to log instead of printing to stdout
        log.add(msg);
      }
  );
  return Zone.current.fork(specification: spec).run(testFn);
}
