import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

final _logger = Logger('exception_chain');

enum Foo {
  bar,
}

void main() {
  PrintAppender.setupLogging();
  group('main', () {
    test('json error', () {
      try {
        json.encode(Foo.bar);
      } catch (e, stackTrace) {
        _logger.fine('Got error.', e, stackTrace);
        final formatted = DefaultLogRecordFormatter().format(
          LogRecord(Level.FINE, 'xxx', 'xxx', e, stackTrace),
        );
        expect(formatted, contains('has no instance method'));
      }
    });
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
  });
}
