import 'package:logging_appenders/logging_appenders.dart';
import 'package:logging_appenders/src/exception_chain.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'package:logging/logging.dart';

final _logger = Logger('exception_chain');

void main() {
  PrintAppender.setupLogging();
  test('Simple chained exception', () {
    try {
      try {
        int.parse('a');
      } catch (e, stackTrace) {
        throw Exception('unable to parse').causedBy(e, stackTrace);
      }
      fail('unreachable');
    } on Exception catch (e, stackTrace) {
      expect(e.getCausedByException(), isNotNull);
      expect(e.getCausedByException()?.error, isFormatException);
      expect(e.toStringWithCause(), contains('FormatException'));
      _logger.finer('toStringWithCause: ${e.toStringWithCause()}');
      _logger.finer('catched exception.', e, stackTrace);
    }
  });
}
