import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:logging_appenders/src/exception_chain.dart';
import 'internal/ansi.dart' as ansi;

/// Base class for formatters which are responsible for converting
/// [LogRecord]s to strings.
abstract class LogRecordFormatter {
  const LogRecordFormatter();

  /// Should write the formatted output of [rec] into [sb].
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

typedef CausedByInfo = ({Object error, StackTrace? stack});
typedef CausedByInfoFetcher = CausedByInfo? Function(Object? error);

/// Opinionated log formatter which will give a decent format of [LogRecord]
/// and adds stack trace and error messages if they are available.
class DefaultLogRecordFormatter extends LogRecordFormatter {
  const DefaultLogRecordFormatter();

  static List<CausedByInfoFetcher> causedByFetchers = [
    (error) => error is Exception ? error.getCausedByException() : null,
    (error) => error is JsonUnsupportedObjectError && error.cause != null
        ? (error: error.cause ?? '', stack: null)
        : null,
  ];

  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) {
    sb.write('${rec.time} ${rec.level.name} '
        '${rec.loggerName} - ${rec.message}');

    void formatErrorAndStackTrace(final Object? error, StackTrace? stackTrace) {
      if (error != null) {
        sb.writeln();
        sb.write('### ${error.runtimeType}: ');
        sb.write(error);
      }
      // ignore: avoid_as
      final stack = stackTrace ?? (error is Error ? (error).stackTrace : null);
      if (stack != null) {
        sb.writeln();
        sb.write(stack);
      }
      final causedBy = causedByFetchers
          .map((e) => e(error))
          .where((x) => x != null)
          .firstOrNull;
      if (causedBy != null) {
        sb.write('### Caused by: ');
        formatErrorAndStackTrace(causedBy.error, causedBy.stack);
      }
    }

    formatErrorAndStackTrace(rec.error, rec.stackTrace);

    return sb;
  }
}

/// dart:io logger which adds ansi escape characters to set the color
/// of the output depending on log level.
class ColorFormatter extends LogRecordFormatter {
  const ColorFormatter(
      [this.wrappedFormatter = const DefaultLogRecordFormatter()]);

  final LogRecordFormatter wrappedFormatter;
  static final Map<Level, _AnsiCombination?> _colorCache = {};

  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) {
    final color =
        _colorCache.putIfAbsent(rec.level, () => _colorForLevel(rec.level));
    if (color != null) {
      sb.write(color.escape);
      wrappedFormatter.formatToStringBuffer(rec, sb);
      sb.write(color.resetEscape);
    } else {
      wrappedFormatter.formatToStringBuffer(rec, sb);
    }
    return sb;
  }

  _AnsiCombination? _colorForLevel(Level level) {
    if (level <= Level.FINE) {
      return _AnsiCombination.combine([ansi.styleDim, ansi.lightGray]);
    }
    if (level <= Level.INFO) {
      return null;
    }
    if (level <= Level.WARNING) {
      return _AnsiCombination.combine([ansi.magenta]);
    }
    if (level <= Level.SEVERE) {
      return _AnsiCombination.combine([ansi.red]);
    }
    return _AnsiCombination.combine([ansi.red, ansi.styleBold]);
  }
}

class _AnsiCombination {
  _AnsiCombination._(this.escape, this.resetEscape);

  _AnsiCombination.combine(List<ansi.AnsiCode> codes)
      : this._(codes.map((code) => code.escape).join(),
            codes.map((code) => code.reset?.escape).join());

  final String escape;
  final String resetEscape;
}
