import 'package:io/ansi.dart' as ansi;
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';

abstract class LogRecordFormatter {
  const LogRecordFormatter();

  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb);

  String format(LogRecord rec) =>
      formatToStringBuffer(rec, StringBuffer()).toString();
}

/// Formatter which can be easily configured using a function block.
class BlockFormatter extends LogRecordFormatter {
  BlockFormatter._(this.block);

  BlockFormatter.formatRecord(String Function(LogRecord rec) formatter)
      : this._((rec, sb) => sb.write(formatter(rec)));

  final void Function(LogRecord rec, StringBuffer sb) block;

  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) {
    block(rec, sb);
    return sb;
  }
}

class DefaultLogRecordFormatter extends LogRecordFormatter {
  const DefaultLogRecordFormatter();

  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) {
    sb.write('${rec.time} ${rec.level.name} '
        '${rec.loggerName} - ${rec.message}');

    if (rec.error != null) {
      sb.write(rec.error);
    }
    // ignore: avoid_as
    final stackTrace = rec.stackTrace ??
        (rec.error is Error ? (rec.error as Error).stackTrace : null);
    if (stackTrace != null) {
      sb.write(stackTrace);
    }
    return sb;
  }
}

class ColorFormatter extends LogRecordFormatter {
  const ColorFormatter(
      [this.wrappedFormatter = const DefaultLogRecordFormatter()]);

  final LogRecordFormatter wrappedFormatter;
  static final Map<Level, AnsiCombination> _colorCache = {};

  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) {
    final color = _colorCache.putIfAbsent(rec.level, () => _colorForLevel(rec.level));
    if (color != null) {
      sb.write(color.escape);
      wrappedFormatter.formatToStringBuffer(rec, sb);
      sb.write(color.resetEscape);
    } else {
      wrappedFormatter.formatToStringBuffer(rec, sb);
    }
    return sb;
  }

  AnsiCombination _colorForLevel(Level level) {
    if (level <= Level.FINE) {
      return AnsiCombination.combine([ansi.styleDim, ansi.lightGray]);
    }
    if (level <= Level.INFO) {
      return null;
    }
    if (level <= Level.WARNING) {
      return AnsiCombination.combine([ansi.magenta]);
    }
    if (level <= Level.SEVERE) {
      return AnsiCombination.combine([ansi.red]);
    }
    return AnsiCombination.combine([ansi.red, ansi.styleBold]);
  }
}

class AnsiCombination {
  AnsiCombination._(this.escape, this.resetEscape);
  AnsiCombination.combine(List<AnsiCode> codes) :
      this._(codes.map((code) => code.escape).join(), codes.map((code) => code.reset?.escape).join());

  final String escape;
  final String resetEscape;
}
