import 'dart:async';

class TestUtils {
  static T overridePrint<T>(List<String> log, T Function() testFn) {
    final spec = ZoneSpecification(print: (_, __, ___, String msg) {
      // Add to log instead of printing to stdout
      log.add(msg);
    });
    return Zone.current.fork(specification: spec).run(testFn);
  }
}
