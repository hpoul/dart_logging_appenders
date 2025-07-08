import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';

final _logger = Logger('example');

void main() {
  Logger.root.level = Level.ALL;
  final appender = PrintAppender.setupLogging(stderrLevel: Level.SEVERE);
  //  Equal to:
  //  final appender = PrintAppender(formatter: const ColorFormatter())
  //    ..attachToLogger(Logger.root);
  _logger.fine('Lorem ipsum');
  _logger.info('An important info message');
  _logger.severe('This is bad.');
  _logger.shout('This is just impolite');

  Isolate.run(_isolateWork, debugName: 'Child Isolate');
  Isolate.run(_isolateWork);

  // optionally dispose of the appender.
  appender.dispose();
}

void _isolateWork() {
  // Child isolates need to setup logging again.
  PrintAppender.setupLogging();
  _logger.fine('Hello world from child!');
}
