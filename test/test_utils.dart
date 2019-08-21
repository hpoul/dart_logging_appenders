import 'dart:async';

import 'package:logging/logging.dart';

class TestUtils {
  static T overridePrint<T>(List<String> log, T Function() testFn) {
    final spec = ZoneSpecification(print: (_, __, ___, String msg) {
      // Add to log instead of printing to stdout
      log.add(msg);
    });
    return Zone.current.fork(specification: spec).run(testFn);
  }

  static LogRecord logRecord(String message, {Level level = Level.FINE}) =>
      LogRecord(level, message, 'test_logger');
}
