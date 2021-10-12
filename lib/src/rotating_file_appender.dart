import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/internal/dummy_logger.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

final _logger = DummyLogger('logging_appenders.rotating_file_appender');

class RotatingFileAppender extends BaseLogAppender {
  RotatingFileAppender({
    LogRecordFormatter? formatter,
    required this.logPath,
    required this.name,
    this.rotateAtSizeBytes = 10 * 1024 * 1024,
  }) : super(formatter) {
    _outputFile = null;

    _checkRotate();
  }

  @visibleForTesting
  static Logger get debugLogger => _logger;

  /// (Absolute) (ie. the current log file path).
  final String logPath;

  final String name;

  /// The size in bytes we allow a file to grow before rotating it.
  final int rotateAtSizeBytes;

  File? _outputFile;

  bool _defaultRule(File file) {
    final length = file.lengthSync();
    if (length > rotateAtSizeBytes) {
      return true;
    } else {
      return false;
    }
  }

  @override
  void handle(LogRecord record) {
    if (record.loggerName == _logger.fullName) {
      // ignore my own log messages.
      return;
    }

    _checkRotate();

    try {
      _outputFile!.writeAsStringSync(formatter.format(record) + '\r\n',
          mode: FileMode.append, encoding: utf8, flush: true);
    } catch (error, stackTrace) {
      print('error while writing log $error $stackTrace');
      _logger.warning('Error while writing log.', error, stackTrace);
    }
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
  }

  Future<void> _checkRotate({String ext = '.log'}) async {
    // check current _outputFile
    if (_outputFile != null) {
      if (_defaultRule(_outputFile!)) {
        _outputFile = null;
      }
    }

    var result = '';
    try {
      final files = Directory(logPath).listSync();
      for (var f in files) {
        if (FileSystemEntity.isFileSync(f.path) &&
            extension(f.path).toLowerCase() == ext) {
          final index = f.path.toLowerCase().indexOf('_$name.');
          if (index != -1) {
            final m = f.path.substring(index - 'yyyyMMdd_HHmmss'.length, index);
            final _m = m.substring(0, 4) +
                '-' +
                m.substring(4, 6) +
                '-' +
                m.substring(6, 8) +
                m.substring(8, 11) +
                ':' +
                m.substring(11, 13) +
                ':' +
                m.substring(13, m.length);
            final date = DateFormat('yyyy-MM-dd_HH:mm:ss').parse(_m);
            // same day
            if (date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day) {
              // check file size
              try {
                if (!_defaultRule(File(f.path))) {
                  result = f.path;
                  _outputFile ??= File(f.path);
                  break;
                }
              } on FileSystemException catch (_) {
                print(_);
              } catch (e, stackTrace) {
                _logger.warning(
                    'Error while checking file legnth.', e, stackTrace);
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.warning('Error while checking file information.', e, stackTrace);
    }

    if (result == '') {
      // not found old log file
      final now = DateTime.now();
      result =
          '${NumberFormat('####').format(now.year)}${NumberFormat('00').format(now.month)}${NumberFormat('00').format(now.day)}_${NumberFormat('00').format(now.hour)}${NumberFormat('00').format(now.minute)}${NumberFormat('00').format(now.second)}_$name.log';
      _outputFile = File('$logPath$separator$result');
      _outputFile!.createSync(recursive: true);
    }
  }
}

/// A wrapper LogHandler which will buffer log records until the future provided by
/// the [builder] method has resolved.
class AsyncInitializingLogHandler<T extends BaseLogAppender>
    extends BaseLogAppender {
  AsyncInitializingLogHandler({this.builder}) : super(null) {
    builder!().then((newLogHandler) {
      delegatedLogHandler = newLogHandler;
      _bufferedLogRecords!.forEach(handle);
      _bufferedLogRecords = null;
    });
  }

  List<LogRecord>? _bufferedLogRecords = [];
  Future<T> Function()? builder;
  T? delegatedLogHandler;

  @override
  void handle(LogRecord record) {
    if (delegatedLogHandler != null) {
      return delegatedLogHandler!.handle(record);
    }
    _bufferedLogRecords!.add(record);
  }
}
