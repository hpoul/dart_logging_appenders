import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/src/base_appender.dart';
import 'package:logging_appenders/src/logrecord_formatter.dart';
import 'package:meta/meta.dart';

final _logger = Logger('logging_appenders.rotating_file_appender');

/// A file appender which will rotate the log file once it reaches
/// [rotateAtSizeBytes] bytes. Will keep [keepRotateCount] number of
/// files.
class RotatingFileAppender extends BaseLogAppender {
  RotatingFileAppender({
    LogRecordFormatter formatter,
    @required this.baseFilePath,
    this.keepRotateCount = 3,
    this.rotateAtSizeBytes = 10 * 1024 * 1024,
    this.clock = const Clock(),
  })  : assert(baseFilePath != null),
        super(formatter) {
    _outputFile = File(baseFilePath);
    if (!_outputFile.parent.existsSync()) {
      throw StateError(
          'When initializing file logger, ${_outputFile.parent} must exist.');
    }
    _maybeRotate();
  }

  /// (Absolute) path to base file (ie. the current log file).
  final String baseFilePath;
  /// the number of rotated files to keep.
  /// e.g. if this is 3 we will create `filename`, `filename.1`, `filename.2`.
  final int keepRotateCount;
  /// The size in bytes we allow a file to grow before rotating it.
  final int rotateAtSizeBytes;
  final Duration rotateCheckInterval = const Duration(minutes: 5);
  /// how long to keep log file open. will be closed once this duration
  /// passed without a log message.
  final Duration keepOpenDuration = const Duration(minutes: 2);
  final Clock clock;
  DateTime _nextRotateCheck;
  File _outputFile;
  IOSink _outputFileSink;
  Timer _closeAndFlushTimer;

  /// Returns all available rotated logs, starting from the most current one.
  List<File> getAllLogFiles() =>
      Iterable.generate(keepRotateCount, (idx) => idx)
          .map((rotation) => _fileNameForRotation(rotation))
          .map((fileName) => File(fileName))
          .takeWhile((file) => file.existsSync())
          .toList(growable: false);

  IOSink _getOpenOutputFileSink() =>
      _outputFileSink ??= _outputFile.openWrite(mode: FileMode.append)
        ..done.catchError((dynamic error, StackTrace stackTrace) {
          _logger.warning(
              'Error while writing to logging file.', error, stackTrace);
          return Future<dynamic>.error(error, stackTrace);
        });

  @override
  void handle(LogRecord record) {
    if (record.loggerName == _logger.fullName) {
      // ignore my own log messages.
      return;
    }
    try {
      _getOpenOutputFileSink()
        ..writeln(formatter.format(record))
      // for now always call flush for every line.
        ..flush();
    } catch (error, stackTrace) {
      _logger.warning('Error while writing log.', error, stackTrace);
      _closeAndFlush();
      // try once more.
      _getOpenOutputFileSink()
        ..writeln(formatter.format(record));
    }
    _closeAndFlushTimer?.cancel();
    _closeAndFlushTimer = Timer(keepOpenDuration, () {
      _closeAndFlush();
    });
//    _outputFile.writeAsString(
//        (formatter.formatToStringBuffer(record, StringBuffer())..writeln())
//            .toString(),
//        mode: FileMode.append);
    _maybeRotate();
  }

  String _fileNameForRotation(int rotation) =>
      rotation == 0 ? baseFilePath : '$baseFilePath.$rotation';

  /// rotates the file, if it is larger than
  Future<bool> _maybeRotate() async {
    if (_nextRotateCheck?.isAfter(clock.now()) == true) {
      return false;
    }
    _nextRotateCheck = clock.now().add(rotateCheckInterval);
    try {
      final length = await _outputFile.length();
      if (length < rotateAtSizeBytes) {
        return false;
      }
    } on FileSystemException catch (_) {
      // if .length() throws an error, ignore it.
      return false;
    }
    for (int i = keepRotateCount - 1; i >= 0; i--) {
      final file = File(_fileNameForRotation(i));
      if (file.existsSync()) {
        await file.rename(_fileNameForRotation(i + 1));
      }
    }
    await _closeAndFlush();
    return true;
  }

  Future<void> _closeAndFlush() async {
    if (_outputFileSink != null) {
      try {
        final oldSink = _outputFileSink;
        _outputFileSink = null;
        await oldSink.flush();
        await oldSink.close();
      } catch (e, stackTrace) {
        _logger.warning('Error while flushing, closing stream.', e, stackTrace);
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _closeAndFlush();
    await super.dispose();
  }
}

/// A wrapper LogHandler which will buffer log records until the future provided by
/// the [builder] method has resolved.
class AsyncInitializingLogHandler<T extends BaseLogAppender>
    extends BaseLogAppender {
  AsyncInitializingLogHandler({this.builder}) : super(null) {
    this.builder().then((newLogHandler) {
      delegatedLogHandler = newLogHandler;
      _bufferedLogRecords.forEach(handle);
      _bufferedLogRecords = null;
    });
  }

  List<LogRecord> _bufferedLogRecords = [];
  Future<T> Function() builder;
  T delegatedLogHandler;

  @override
  void handle(LogRecord record) {
    if (delegatedLogHandler != null) {
      return delegatedLogHandler.handle(record);
    }
    _bufferedLogRecords.add(record);
  }
}
