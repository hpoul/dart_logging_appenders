import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

class FakeLogRecordFormatter extends LogRecordFormatter {
  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) =>
      sb..write('msg:${rec.message}');
}

class MockLogRecordFormatter extends Mock implements LogRecordFormatter {
  @override
  String format(LogRecord? rec) =>
      super.noSuchMethod(Invocation.method(#format, [rec])) as String? ?? '';
}

void main() {
  setUpAll(() {
    hierarchicalLoggingEnabled = true;
    LoggingAppenders.internalLogLevel = Level.ALL;
  });
  test('dummy print logger test', () async {
    final printLog = <String>[];
    final dummyLogger = Logger.detached('dummy');
    dummyLogger.level = Level.ALL;
    final formatter = MockLogRecordFormatter();
    when(formatter.format(any)).thenReturn('mock');
    final appender = PrintAppender(formatter: formatter);
    TestUtils.overridePrint(printLog, () {
      appender.attachToLogger(dummyLogger);
      dummyLogger.info('foo', 'bar');
    });

    expect(printLog, equals(['mock']));
    verify(formatter.format(any)).called(1);
  });
  test('Test real print logger', () async {
    // this test basically validates that the default `PrintAppender`
    // implementation does not throw. Especially for dart:web.
    // so tests have to be run using:
    // `> dart run test -p chrome test/print_appender_test.dart`
    final dummyLogger = Logger.detached('dummy');
    final appender = PrintAppender();
    final printLog = <String>[];
    TestUtils.overridePrint(printLog, () {
      appender.attachToLogger(dummyLogger);
      dummyLogger.info('foo', 'bar');
    });
    final webMatcher = RegExp(r'^[0-9- :\.]*?\d\d\d INFO');
    final ioMatcher = RegExp(r'^\[test_suite.*?\] [0-9- :\.]*?\d\d\d INFO');
    final line = printLog.last;
    print('log (isWeb: ${TestUtils.isWeb}): $line');
    expect(ioMatcher.hasMatch(line), TestUtils.isWeb ? isFalse : isTrue);
    expect(webMatcher.hasMatch(line), TestUtils.isWeb ? isTrue : isFalse);
  });
}
