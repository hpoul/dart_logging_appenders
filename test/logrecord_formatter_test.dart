import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:logging_appenders/src/internal/ansi.dart' as ansi;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('testing color output', () {
    final formatter =
        ColorFormatter(BlockFormatter.formatRecord((rec) => 'abc'));

    final fine =
        formatter.format(TestUtils.logRecord('lorem ipsum', level: Level.FINE));
    final fine1 =
        formatter.format(TestUtils.logRecord('lorem ipsum', level: Level.FINE));
    expect(fine, equals(fine1));
    final info =
        formatter.format(TestUtils.logRecord('lorem ipsum', level: Level.INFO));
    expect(fine, isNot(equals(info)));

    final warning = formatter
        .format(TestUtils.logRecord('lorem ipsum', level: Level.WARNING));
    expect(fine, isNot(equals(warning)));

    final severe = formatter
        .format(TestUtils.logRecord('lorem ipsum', level: Level.SEVERE));
    expect(fine, isNot(equals(severe)));
    expect(severe, contains(ansi.red.escape));
  });
}
