import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';

final _logger = Logger('main');

void main() {
  Logger.root.level = Level.ALL;
  final appender = PrintAppender()..attachToLogger(Logger.root);
  _logger.fine('Lorem ipsum');

  // optionally dispose of the appender.
  appender.dispose();
}
