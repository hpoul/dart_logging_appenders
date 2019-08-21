

import 'dart:math';

import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void _logAllLevels(DummyLogger dummyLogger) {
  dummyLogger.finest('finest');
  dummyLogger.finer('finer');
  dummyLogger.fine('fine');
  dummyLogger.config('config');
  dummyLogger.info('info');
  dummyLogger.warning('warning');
  dummyLogger.severe('severe');
  dummyLogger.shout('shout');
}

void main() {
  test('changing levels', () async {
    final log = <String>[];
    final dummyLogger = DummyLogger('foo');
    TestUtils.overridePrint(log, () {
      _logAllLevels(dummyLogger);
    });
    expect(log, isEmpty);
    LoggingAppenders.internalLogLevel = Level.SEVERE;
    TestUtils.overridePrint(log, () {
      _logAllLevels(dummyLogger);
    });
    expect(log, hasLength(2));
  });
}