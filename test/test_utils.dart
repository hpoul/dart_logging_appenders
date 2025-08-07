import 'dart:async';

import 'package:logging/logging.dart';

import 'test_utils.platform.dart'
    if (dart.library.js_interop) 'test_utils.platform.web.dart';

class TestUtils {
  static T overridePrint<T>(List<String> log, T Function() testFn) {
    final spec = ZoneSpecification(
      print: (_, _, _, String msg) {
        // Add to log instead of printing to stdout
        log.add(msg);
      },
    );
    return Zone.current.fork(specification: spec).run(testFn);
  }

  static LogRecord logRecord(String message, {Level level = Level.FINE}) =>
      LogRecord(level, message, 'test_logger');

  static const isWeb = testIsWeb;
}
