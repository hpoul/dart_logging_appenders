import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';

final _logger = Logger('main');

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(PrintAppender().logListener());
  _logger.fine('Lorem ipsum');
}
